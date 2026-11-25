class_name Player
extends CharacterBody3D
# Gatilho de extração: novas regras de locomoção ficam em componentes; agachar
# é dono de colisão/apoio em src/player/agachar.gd, sem ampliar esta casca.

var _rocket: Node

const BARA := preload("res://src/combat/BaraController.gd")
const BARA_NET := preload("res://src/player/BaraNetwork.gd")
const OPE := preload("res://src/combat/OpeController.gd")
const OPE_VFX := preload("res://src/effects/OpeVfx.gd")

signal player_damaged(amount: float, hp: float, mhp: float)
signal aim_assist_changed(on: bool)
signal combat_mode_updated(mode: String, style_id: String, fruit_id: String)
signal anim_name_shown(text: String)

# ============================================================================
#  Jogador = um bloco cinza. Anda (WASD / setas), pula (Espaco).
#  F5 alterna 1a <-> 3a pessoa. Mouse olha. ESC solta o mouse; segure pra sair.
#
#  Sem InputMap: le o teclado direto, entao o projeto roda sem configuracao.
# ============================================================================

const SPEED := 4.2

## Movimentação do Minecraft (andar, correr, agachar, pular, cair): ver MovimentoMinecraft.
var _mc_mov := MovimentoMinecraft.new()
const JUMP_VELOCITY := 16.0

## Quão depressa o corpo alcança a mira. Alto o bastante para não haver atraso
## perceptível entre girar o mouse e o golpe sair na direção nova; baixo o
## bastante para o giro não ser um corte seco. Era 24 no caso parado e 35 no caso
## em movimento — dois números para a mesma coisa, agora um só.
const VELOCIDADE_FACING := 26.0

## Altura da CINTURA a partir dos pés: o pivô de quem gira o corpo inteiro (aú,
## inclinação do wall run) — gira-se em torno do centro de massa, não do chão.
const ALTURA_DO_ROLAMENTO := 0.55

## WALL RUN (fatia 2, 03/10/2026): o corpo inteiro inclina para LONGE da parede,
## girando em volta da cintura (ALTURA_DO_ROLAMENTO) — é o que põe os PÉS na
## parede, como pediu o dono ("os dois pés permanecem próximos ou apoiados").
const INCLINACAO_WALL_RUN := deg_to_rad(26.0)

## Inclinação do wall run (rad, + = para a esquerda) e o repouso guardado dela.
var _incl_parede := 0.0
var _inclinado_na_parede := false
var _pose_repouso_parede := Vector3.ZERO


## WALL RUN: o corpo inteiro inclina para longe da parede girando em volta do eixo
## da FRENTE, com o pivô na CINTURA — a cintura fica onde está, os pés vão para a
## parede e a cabeça para longe dela (é a postura de quem corre apoiado na parede).
## Mesmo cuidado do rolamento de costas: o repouso do modelo é GUARDADO no começo e
## devolvido no fim, nunca suposto.
##
## `lado`: +1/−1 no wall run (parede à direita/esquerda), 0 fora dele. O dono passa
## o do parkour; a cópia remota, o replicado (`net_parede_lado`).
func _inclinar_no_wall_run(delta: float, lado: int) -> void:
	if _char_model == null:
		return
	var alvo := INCLINACAO_WALL_RUN * float(lado)
	_incl_parede = lerpf(_incl_parede, alvo, 1.0 - exp(-14.0 * delta))
	if alvo == 0.0 and absf(_incl_parede) < 0.0005:
		if _inclinado_na_parede:
			_inclinado_na_parede = false
			_incl_parede = 0.0
			_char_model.rotation.z = 0.0
			_char_model.position = _pose_repouso_parede
		return
	if not _inclinado_na_parede:
		_inclinado_na_parede = true
		_pose_repouso_parede = _char_model.position
	_char_model.rotation.z = _incl_parede
	var cintura := Vector3(0.0, ALTURA_DO_ROLAMENTO, 0.0)
	var giro := Basis.from_euler(Vector3(0.0, _char_model.rotation.y, _incl_parede))
	_char_model.position = _pose_repouso_parede + cintura - giro * cintura
const GRAVITY := 32.0        # gravidade reforcada (Godot padrao ~9.8)

## A altura que um pulo simples alcança: v²/2g. Com 16 e 32, exatamente 4,00 m.
const ALTURA_DE_UM_PULO := (JUMP_VELOCITY * JUMP_VELOCITY) / (2.0 * GRAVITY)
## E o teto para começar a Aú — metade dela (2,00 m). Ver `tentar_chute_giratorio`.
const ALTURA_MAX_CHUTE_GIRATORIO := ALTURA_DE_UM_PULO * 0.5
## Até onde o raio procura chão. Acima disso a resposta é "muito alto" de
## qualquer jeito, e um raio infinito custaria mais sem mudar decisão nenhuma.
const ALCANCE_RAIO_CHAO := 40.0
const MOUSE_SENS := 0.0035

# A câmera virou COMPONENTE (Fase 2 — ver docs/ARQUITETURA_PLAYER.md). O rig é
# dono do tremor, do soco de FOV, do balanço, da perspectiva e da distância;
# aqui só sobra a referência a ele e o `_cam` de conveniência para a mira.

# ⚠️ ATALHO DE DESENVOLVIMENTO, E ELE TEM UMA FONTE SÓ DESDE 2026-08-25.
#
# Havia TRÊS escritores da fruta inicial, e os três discordavam: este padrão
# dizia `bara_bara`, o `Main._spawn_player` equipava `mera_mera` (e vencia, por
# ser adiado), e o `test_initial_fruit` cobrava `gura_gura` — nome de uma sessão
# ainda mais antiga. O teste ficou vermelho e ninguém sabia qual dos três estava
# certo, porque não havia "certo": havia três opiniões.
#
# Agora o número mora aqui e os outros dois LEEM. Trocar a fruta de trabalho é
# mexer nesta linha.
#
# ⚠️ E ISTO NÃO É REGRA DE JOGO. A economia das frutas é achar a árvore,
# disputar o fruto e perdê-lo ao morrer (ver `docs/frutas/README.md`). Se este
# atalho chegar ao jogador final, essa economia deixa de existir.
# GATILHO para apagar: quando houver escolha de fruta/personagem no menu.
# A fruta com que todo jogador entra na partida.
#   suke_suke → pika_pika (2026-09-04) → ope_ope (2026-09-08), sempre a pedido do dono.
#
# ⚠️ TROCAR ESTA LINHA MEXE EM MAIS COISA DO QUE PARECE:
#
#   1. A PASSIVA multiplica a velocidade, e o `traco_locomocao` compara o
#      movimento com uma linha de base gravada — byte a byte, com `diff -q`,
#      tolerância ZERO. Medido em `FruitPassiveSystem.gd`: `SPEED` é 4,2 e o
#      `speed_mod` multiplica — pika_pika 1,25 = 5,25; **ope_ope 1,00 = 4,20**,
#      que é o `SPEED` cru. Qualquer troca de fruta reprova o traço inteiro.
#      Ver o item 52 de `docs/LISTA_DE_CORRECOES.md`.
#
#   2. A fruta inicial precisa ter ÁRVORE no mapa, senão quem trocar de fruta
#      numa partida não a recupera. Era o item 51 da lista de correções, e a
#      `pika_pika` era a única jogável sem árvore. A `ope_ope` tem — então esta
#      troca resolve aquele item de lado.
const FRUTA_INICIAL := "ope_ope"

# O que este corpo tem PERMISSÃO de fazer (combate, dash, pulo duplo, técnicas).
# A arena usa tudo liberado; o Modo História troca por `civil()` antes do
# `add_child`. A trava fica na entrada de cada pedido — ver `capacidades.gd`.
var capacidades := CapacidadesDoJogador.completas()
# Combate direcional do Modo História (docs/PLANO_COMBATE_HISTORIA.md). NULO fora
# dele: quem instala é `ModoHistoria.instalar_combate_direcional`, e com ele nulo
# todo desvio que o consulta é inerte — a arena não passa por nenhum.
var combate_direcional: ExecutorCorpoACorpo = null
# A entrada do jogador para esse combate (clique + direção pelo mouse). Nula junto.
var entrada_combate_direcional: EntradaCorpoACorpo = null
## O clique do Minecraft (V5, `CliqueDeBlocos`): quebra/coloca blocos e bate com recarga no lugar do soco direcional. Nulo = o soco de sempre.
var clique_de_blocos: CliqueDeBlocos = null
# Números da fruta NESTE modo (custo de energia, recarga, dano). NULO na arena, e nulo
# quer dizer "faz o de sempre": `Balance`, `SkillSystem` e `ENERGY_SKILL`. Quem instala é
# o `ModoHistoria` — a história tem energia 10, onde o custo de 180 da arena travaria tudo.
var perfil_de_frutas: PerfilDeFrutas = null
# O voo curto da fruta (F no Modo História). Como o dash: ele devolve a velocidade e
# quem escreve é a etapa de locomoção. Parado, é inerte.
var _voo := VooFoguete.new()
var _phoenix: Node3D

# A malha do foguete que o jogador VIRA durante o voo (decisão do dono, 30/09/2026).
# Existe enquanto `_voo.forma_de_foguete()` for verdade — ver `_sincronizar_forma_de_foguete`.
const FORMA_DE_FOGUETE := preload("res://src/effects/forma_de_foguete.gd")
var _forma_de_foguete: Node3D = null
# O indicador de mira da fruta (linha no Z, pontos no X, ponto de queda no C). Nasce na
# primeira tecla segurada e só no corpo de quem joga; na arena nunca aparece, porque lá
# não existe `perfil_de_frutas`.
const MIRA_DE_FRUTA := preload("res://src/player/mira_de_fruta.gd")
var _mira_fruta: Node3D = null
# Onde o corpo reaparece sem placar (queda no vazio). A arena mantém o centro da
# plataforma; o Modo História passa o spawn do arquivo de mapa.
var ponto_de_renascimento: Vector3 = Scoreboard.RESPAWN
## Modo História (27/10/2026, `MorteDoJogador`): quem trata a morte (câmera lenta, texto, fade) e DEPOIS pede o respawn.
## Vazio na arena: lá o placar manda o respawn na hora, como sempre.
var ao_morrer := Callable()
var morrendo := false
# Os "clones" translúcidos que ficam para trás na corrida (`AfterimageTrail`). É
# efeito de poder da arena; o Civil do Modo História corre sem eles (pedido do
# dono, 14/09/2026). Desligado, o rastro que já existia some sozinho.
var ecos_de_movimento_ligados := true
# COLISOR EM CÁPSULA (01/10/2026, decisão do dono: SÓ no Modo História). A caixa de
# fundo reto apoia numa quina em qualquer encosta e o centro (onde estão os pés)
# fica no ar — medido na Ilha Inicial: +11 cm a 4,6°, +27 cm a 21° —, e ela não
# sobe degrau nenhum. A cápsula toca a encosta embaixo do centro (≈4 cm a 21°) e
# passa por cima de beirada baixa. A arena continua com a caixa. Definir ANTES do
# `add_child` (o colisor nasce no `_ready`); quem liga é `ModoHistoria.colocar_civil`.
var colisor_capsula := false
## Knockback no estilo Minecraft (23/10/2026): só o jogador do Modo História
## (`ModoHistoria.instalar_combate_direcional`). Nulo = o empurrão da arena.
var knockback_minecraft: KnockbackMinecraft = null

var current_fruit_id: String = FRUTA_INICIAL
var active_style: String = "basic"
# ⚠️ TRÊS MODOS desde 2026-09-06, escolhidos por TECLA (1, 2, 3). Era um par
# ("fruit"/"style") alternado no R, e o dono pediu seleção direta:
#
#     1 -> fruit   Akuma no Mi (Z/X/C/V da fruta)
#     2 -> style   estilo de luta (Z/X/C/V do estilo)
#     3 -> sword   Yoru: dois M1 e técnicas próprias Z/X/C/V
#
# Quem escolhe QUAL fruta / QUAL estilo continua sendo o menu do M.
#
# No modo espada o cast de fruta/estilo segue barrado por pode_conjurar.
# As técnicas Yoru possuem entrada própria, validada pelo servidor.
var combat_mode: String = "fruit" # "fruit", "style" ou "sword"
var speed_multiplier: float = 1.0
## Água rasa (Modo História, 01/10/2026): quem calcula é o `JogadorNaAgua`; 1,0 = seco.
var fator_da_agua: float = 1.0
## Na água funda (`JogadorNaAgua`, docs/AGUA_PLANO.md): "" = fora; "nadando" = flutua e
## nada; "afundando" = usuário de Akuma no Mi totalmente submerso (não nada, afunda).
## Nesses modos a gravidade dá lugar a `agua_vertical` (velocidade vertical pedida) e o
## pulo do parkour não age — o Espaço sobe, o Ctrl desce.
var modo_na_agua: String = ""
var agua_vertical: float = 0.0
var controle_da_agua: Node = null
## Controlador da montaria do modo história; null fora da sela.
var montaria: Node = null
## Posto de comando de barco da campanha; null enquanto anda/nada normalmente.
var navegacao: Node = null
var jump_multiplier: float = 1.0
## Velocidade e Pulo do Mine Piece na história (`VelocidadeMinePiece`, A6b): efeitos que sobem ao correr/agachar. 1 fora dela.
var velocidade_mod: float = 1.0
var pulo_mod: float = 1.0

# Vida (barra verde, HUD) — máx 2048. Foco continua no knockback pra fora do mapa,
# mas agora o dano importa e é mostrado.
# VIDA/ENERGIA/EMPURRÃO -> src/player/health_controller.gd (Fase 8).
#
# Estas quatro são API PÚBLICA — `StatsHud`, `TargetSystem` e `GomuArm` leem, e
# os testes escrevem em `energy` para montar cenário. Por isso aqui a vista tem
# getter E setter: continua havendo UM dono do valor (o componente), mas a API
# não quebra. A regra "vista sem setter" vale para campo cujo write de fora é
# bug — não é o caso destes.
var _vida := HealthController.new()
## Arremesso com derrubada (4º soco do Boss): voa, cai deitado, levanta.
var _arremesso := PlayerArremesso.new()
var _mira := Mira.new()
var health: float:
	get: return _vida.vida
	set(v): _vida.vida = v
var max_health: float:
	get: return _vida.vida_max
	set(v): _vida.vida_max = v
# Energia (barra azul, HUD) — máx 4096. Regenera com o tempo; skills consomem.
var energy: float:
	get: return _vida.energia
	set(v): _vida.energia = v
var max_energy: float:
	get: return _vida.energia_max
	set(v): _vida.energia_max = v
const ENERGY_BULLET := 10.0        # por bala da rajada Z
const ENERGY_SKILL := 180.0        # por skill lançada
const ENERGIA_INVISIBILIDADE_POR_SEG := 55.0
# SILÊNCIO (Yami) -> CastController (passo 6d). Vistas: `is_suppressed` é lido
# em 5 pontos aqui e por sondas de fora.
var is_suppressed: bool:
	get: return _cast.suprimido()
var suppression_timer: float:
	get: return _cast.tempo_de_silencio()

var current_style_idx: int = 0
const STYLES_LIST: Array[String] = ["karate_tritao", "pacifista", "mink", "boxe", "cyborg", "teste_animacao"]

# ---- FSM DE COMBATE E INPUT BUFFER (Fase Nova) ----
var _fsm: PlayerStateMachine
var _input_buffer: Array = []
const BUFFER_WINDOW_MS = 400

func _add_input_to_buffer(action: String) -> void:
	_input_buffer.push_back({"action": action, "time": Time.get_ticks_msec()})
	if _input_buffer.size() > 10:
		_input_buffer.pop_front()

func _consume_input(action: String) -> bool:
	if esta_capturado_pelo_vento():
		return false
	if _arremesso.ativo():
		return false
	if has_meta("custom_pose") and get_meta("custom_pose") == "knockdown":
		return false
	if has_meta("is_frozen") and get_meta("is_frozen"):
		return false
		
	var current_time = Time.get_ticks_msec()
	_input_buffer = _input_buffer.filter(func(i): return current_time - i["time"] <= BUFFER_WINDOW_MS)
	for i in range(_input_buffer.size()):
		if _input_buffer[i]["action"] == action:
			_input_buffer.remove_at(i)
			return true
	return false

var hit_confirmed: bool = false

# ---------------------------------------------------------- GRUPOS DE ESTADO
# O "Attacking" único virou três fases em 2026-08-25 (§4.1 do
# PLANO_COMBATE_BATTLEGROUNDS). Quem só quer saber "está no meio de um golpe?"
# pergunta a estas listas em vez de repetir os três nomes — repetir era como o
# `in ["Attacking", "Casting", "Stunned"]` foi ficando para trás.
#
# "Casting" nunca existiu como nó (mesma armadilha do "Stunned"); fica na lista
# porque o dia que existir já entra funcionando, e listar um nome a mais não
# custa nada — o teste é de pertinência, não de existência.
const ESTADOS_DE_ATAQUE := ["AttackStartup", "AttackActive", "AttackRecovery"]
const ESTADOS_TRAVADOS := ["AttackStartup", "AttackActive", "AttackRecovery", "Casting", "Stunned"]

# Está no meio de um golpe do combo (qualquer das três fases)?
func esta_atacando() -> bool:
	# No Modo História o golpe é do executor e a FSM fica em Idle.
	if combate_direcional != null:
		return combate_direcional.atacando()
	return _fsm != null and _fsm.state != null and _fsm.state.name in ESTADOS_DE_ATAQUE

# O cast vive em src/player/cast_controller.gd (passo 6c). Aqui só as VISTAS —
# `_charging` é lido por 5 arquivos de fora.
var _cast := CastController.new()
var _charging: bool:
	get: return _cast.carregando()
var _charge_slot: String:
	get: return _cast.slot()
# Nº de série do cast atual. Cada `begin_charge` emite um novo. O temporizador de
# 0.3 s que apaga `is_casting` no fim do golpe carrega o número do golpe DELE e só
# apaga se ainda for o mesmo — senão o temporizador do golpe ANTERIOR apagava o
# `is_casting` do golpe SEGUINTE, e o bloco do _physics_process lia isso como
# "cast interrompido" e engolia a skill seguinte.
var _cast_token: int:
	get: return _cast.token()
	# _movement_locked_timer removido (FSM gerencia)
# IMPULSO EXTERNO (knockback). NÃO pode viver dentro de `velocity`: o bloco de
# locomoção faz `velocity.x = dir.x * speed` — ATRIBUIÇÃO, não soma — e apagaria
# o empurrão no quadro seguinte. Foi exatamente isso que fez ninguém tomar
# knockback, nem em rede nem em um-jogador. Vive aqui, decai sozinho, e é somado
# à velocidade logo antes do move_and_slide.

var _yaw := 0.0     # rotacao horizontal da camera
var _pitch := PITCH_DE_DESCANSO # rotacao vertical da camera
## A câmera de 3ª pessoa DESCANSA olhando ~14° para baixo. O voo da Rocket trata esse
## ângulo como NIVELADO: sem isso o foguete mergulharia sozinho com o mouse parado.
const PITCH_DE_DESCANSO := -0.25
# PARKOUR -> src/player/parkour_controller.gd (Fase 4). Aqui só as VISTAS.
var _parkour := ParkourController.new()
# LOCOMOÇÃO NO CHÃO -> src/player/locomocao_chao.gd (02/10/2026, fatia 1 de
# docs/PARKOUR_MIRRORS_EDGE_PLANO.md): arrancada, frenagem, giro, curva e inclinação.
const LocomocaoChao = preload("res://src/player/locomocao_chao.gd")
var _loco_chao = LocomocaoChao.new()
## Deslize legado: Ctrl passou a agachar em 20/10/2026.
const Deslize = preload("res://src/player/deslize.gd")
var _deslize = Deslize.new()
var _agachar = preload("res://src/player/agachar.gd").new()
const SubirDegrau := preload("res://src/player/subir_degrau.gd")
var _encolhido := false
var _colisor_inteiro := {}
## A FRENTE (decisão do dono, 02/10/2026): correndo livre o corpo segue o
## MOVIMENTO; atacando, usando skill ou mirando ele vira para a MIRA e fica assim
## por COMBATE_SEGURA segundos depois da última ação. Substitui a regra de 27/08
## ("sempre a mira") fora do combate — o golpe continua saindo para onde o corpo
## aponta, porque em combate o corpo aponta para a mira.
const COMBATE_SEGURA := 0.8
const VELOCIDADE_FACING_LIVRE := 16.0
const VELOCIDADE_FACING_GIRO := 34.0
var _combate_t := 0.0
var _is_climbing: bool:
	get: return _parkour.escalando()
var max_geppo: int:
	get: return _parkour.max_geppo
	set(v): _parkour.max_geppo = v
var _geppo_count: int:
	get: return _parkour.geppos()

var _camera: CameraRig        # componente: câmera, tremor, FOV, balanço, tela
var _gear2: Gear2Controller   # componente: a transformação Gear 2 (slot V da Gomu)
var _cam: Camera3D            # atalho para `_camera.camera()` — a mira usa muito


# Sprint = Shift segurado com direção. Usado pela câmera e pelos efeitos de tela;
# o movimento tem a própria checagem em _physics_process.
## Público para o combate direcional (golpe de corrida do Epic Fight).
func esta_correndo() -> bool:
	return _is_sprinting() or get_meta("forcar_corrida", false)      # meta: sonda de teste (o Shift real não existe em headless)


func _is_sprinting() -> bool:
	return not _agachar.ativo and Input.is_key_pressed(KEY_SHIFT) and velocity.length_squared() > 0.5
var _long_jump_t: float:
	get: return _parkour.janela_impulso()
# O PEDIDO do jogador neste quadro (teclas + base da câmera) -> move_frame.gd.
# Vive entre quadros porque a borda do Espaço precisa lembrar o quadro anterior
# — era o campo `_space_was`, que saiu do Player junto.
var _quadro := MoveFrame.new()
# Janela da animação de ROLAMENTO. Tinha DOIS donos — o pouso de precisão e o
# dash escreviam nela direto. Virou PEDIDO (`pedir_rolamento`), no mesmo padrão
# do `pedir_shake` da câmera: quem quer rolar pede, o Player é o dono do prazo.
var _roll_t: float = 0.0
# DASH (Q): esquiva curta e invencível. A DISTÂNCIA é o parâmetro de design; a
# velocidade sai dela. Assim mudar o alcance não obriga a recalcular nada, e o
# alcance fica escrito em metros no código em vez de escondido num multiplicador.
#
# VELOCIDADE DO DASH (pedido do dono do projeto, 2026-08-10): era 4 m em 0,4 s =
# 10 m/s, pouco mais que o dobro da caminhada (4,2 m/s) — o dash parecia um passo
# apressado, não uma esquiva. Agora 6 m em 0,28 s = **21,4 m/s**, mais de 2× o
# que era.
#
# Subi as duas pontas de propósito, e elas fazem coisas diferentes:
#   • encurtar o TEMPO é o que dá o tranco (a esquiva sai do lugar antes do
#     golpe chegar) — é daqui que vem a sensação de velocidade;
#   • aumentar a DISTÂNCIA é o que faz a esquiva valer taticamente, senão você
#     sai rápido e continua dentro da área do golpe.
#
# Para calibrar: mexa na DISTÂNCIA para mudar alcance e no TEMPO para mudar o
# tranco. A velocidade é consequência dos dois, não um terceiro botão.
#
# Os números e o estado da esquiva moram em src/player/dash_controller.gd
# (Fase 4). Aqui ficam só as VISTAS, para quem observa de fora.
var _dash := DashController.new()
# O Q no ar é outro componente (15/10/2026): habilidade comprada, com energia e recarga.
var _dash_ar := DashNoAr.new()
## Alguma das duas esquivas (roll no chão, dash no ar) está andando com o corpo.
func esquivando() -> bool:
	return _dash.ativo() or _dash_ar.ativo()
var _dash_t: float:
	get: return _dash.tempo()
var _dash_dir: Vector3:
	get: return _dash.direcao()
var _dash_cooldown: float:
	get: return _dash.recarga()
# Mera Mera Z: rajada de balas de fogo (segura pra atirar; para ao soltar ou 8 balas).
# Rajada Z e pistola da Yami -> src/player/disparo_sustentado.gd (passo 6a).
# Aqui só as VISTAS.
var _disparo := DisparoSustentado.new()
const FootDustController = preload("res://src/player/foot_dust_controller.gd")
const FallImpactController = preload("res://src/player/fall_impact_controller.gd")
const AirSlamFXClass = preload("res://src/effects/AirSlamFX.gd")
const SpinKickFXClass = preload("res://src/effects/SpinKickFX.gd")
const ContextualMeleeData = preload("res://src/combat/contextual_melee.gd")
const ContextualMeleeFXClass = preload("res://src/effects/contextual_melee_fx.gd")
const AfterimageTrail = preload("res://src/player/afterimage_trail.gd")
const IronBodyController = preload("res://src/player/iron_body_controller.gd")
var _poeira_dos_pes := FootDustController.new()
var _impacto_de_queda := FallImpactController.new()
var _ecos_de_movimento := AfterimageTrail.new()
var _corpo_de_ferro := IronBodyController.new()
var _rapid_fire: bool:
	get: return _disparo.rajada_ativa()
var _gun_recoil: float = 0.0   # coice da rajada Z (1->0 por tiro) p/ a pose de mira
var _pistols: Array:           # pistolas nas DUAS mãos (visíveis só na rajada Z)
	get: return _rig.pistolas() if _rig else []
var _yami_pistol_active: bool:
	get: return _disparo.yami_ativa()

# ---- BUKI BUKI: arma empunhada + munição (regra nova, 2026-08-11) ----
# A fruta virou um jogo de FPS: a tecla do slot SACA a arma, ela FICA na mão, o
# botão esquerdo atira, e a munição é a penalidade. Zerou a bala (ou trocou de
# slot) -> a arma some e AQUELE slot entra em recarga. Ver src/effects/BukiFX.gd.
#
# ONDE MORA A MUNIÇÃO — os dois lados, de propósito:
#   • `_buki_municao` é do DONO do corpo. É o que a HUD mostra e o que decide a
#     cadência local; precisa ser local senão o contador só se mexeria depois do
#     ida-e-volta de rede e a arma pareceria travada.
#   • `_srv_buki_municao` é do SERVIDOR (só a cópia autoritativa a usa). É ela
#     que autoriza o disparo em `_do_server_bullet`: sem bala, nenhuma
#     `DamageZone` nasce. Cliente mentindo não fere ninguém.
# O dono desconta ao pedir; o servidor desconta ao criar. Empate garantido
# porque os dois partem do mesmo número e o canal é `reliable`.
# O estado do arsenal vive em src/player/buki_controller.gd (Fase 5). Aqui só
# as VISTAS — os RPCs e a HUD continuam falando com o Player.
var _buki := BukiController.new()
var _buki_weapon: String:
	get: return _buki.arma()
var _buki_municao: int:
	get: return _buki.municao()
var _buki_scope: bool:
	get: return _buki.luneta()
var _buki_visual: String:
	get: return _buki.visual()
var _srv_buki_arma: String:
	get: return _buki._srv_arma
var _srv_buki_municao: int:
	get: return _buki.servidor_municao()
# As armas e o pivô são MONTADOS pelo rig (nascem e morrem com o modelo); quem
# decide qual aparece é o combate, aqui. Era o conflito de dois donos que o
# relatório apontou.
var _buki_armas: Dictionary:        # slot -> Node3D pré-construído (oculto)
	get: return _rig.armas_buki() if _rig else {}
var _buki_pivot: Node3D:            # pivô do canhão-corpo (X): gira com a mira
	get: return _rig.pivo_buki() if _rig else null
var _fruit_cooldowns: Dictionary = {"Z": 0.0, "X": 0.0, "C": 0.0, "V": 0.0}
var _style_cooldowns: Dictionary = {"Z": 0.0, "X": 0.0, "C": 0.0, "V": 0.0}
var _skill_cooldowns: Dictionary:
	get:
		if combat_mode == "sword" and _yoru_combat:
			return {"Z": _yoru_combat.cooldown("Z"), "X": _yoru_combat.cooldown("X"),
				"C": _yoru_combat.cooldown("C"), "V": _yoru_combat.cooldown("V")}
		return _fruit_cooldowns if combat_mode == "fruit" else _style_cooldowns
## ============================================================================
##  TRAVA PÓS-FRUTA (pedido do dono, 2026-09-01)
##
##  "adicionar, após o uso de qualquer ataque de fruta, um contador quadrado de
##   5 segundos como o contador da estrelinha/Aú na tela; durante esse tempo o
##   usuário não conseguirá usar os poderes de fruta, e o tempo de recarga das
##   frutas é PAUSADO até os 5 segundos se passarem."
##
##  ⚠️ ELA PAUSA AS RECARGAS, NÃO CORRE JUNTO COM ELAS. É a diferença que dá
##  sentido à mecânica: se as duas contassem ao mesmo tempo, a trava seria
##  invisível em toda skill de recarga maior que 5 s — que é quase todas. Somando
##  em série, cada golpe custa 5 s a mais, e o ritmo do combate de fruta muda de
##  verdade.
## ============================================================================
## ⚠️ DESLIGADA em 2026-09-13 (pedido do dono: "vai ser refeito de outra forma
## mais tarde"). Era 5,0. Com 0 nada arma: os poderes não travam, as recargas não
## pausam e o contador (`TravaFrutaHud`) fica escondido. O mecanismo continua
## inteiro — religar é trocar este número. GATILHO: quando a trava nova for
## desenhada, substituir esta constante e o `test_trava_pos_fruta` junto.
const TRAVA_POS_FRUTA := 0.0
var _trava_pos_fruta: float = 0.0
## INTERVALO ENTRE GOLPES DE FRUTA (pedido do dono, 07/10/2026): "um ataque só pode ser
## lançado 0,5 segundos após o outro". Todas as frutas, arena e história. Só espaça os
## golpes: NÃO pausa recarga nenhuma (a trava acima pausava). A skill do Builder escolhe
## o seu no editor (`configuracoes.intervalo_depois`). O servidor confere com folga.
const INTERVALO_ENTRE_GOLPES := 0.5
var _intervalo_golpe: float = 0.0

var _combo_breaker_cooldown: float = 0.0
var aim_assist: bool = false   # Haki da Observação (liga/desliga no E)
var _gura_rush_active := false
# Movimento pedido por uma skill do Builder (`ExecutorDeSkill`), renovado a cada quadro
# de física: se o executor some, o pedido expira sozinho em 2 quadros.
var _mov_skill_vel := Vector3.ZERO
var _mov_skill_vertical := false
var _flutuar_por_skill := false
var _mov_skill_quadro := -100
var _gura_rush_timer := 0.0
var _gura_rush_dir := Vector3.ZERO
var _gura_rush_target: Node3D = null
var _gura_grab_timer := 0.0
var _bomu_rush_active := false
var _bomu_rush_timer := 0.0
var _bomu_grab_timer := 0.0
var _bomu_rush_dir := Vector3.ZERO
var _bomu_rush_target: Node3D = null
var _bomu_hand_charge: Node3D = null
var _mink_bite_dash := false
var _mink_bite_timer := 0.0
var _mink_bite_dir := Vector3.ZERO
var _mink_bite_target: Node3D = null
var _mink_hold_timer := 0.0
# A investida só é punida quando a mordida CONFIRMA o agarrão. Errar é uma
# abertura curta de movimento, não uma habilidade perdida.
const RECARGA_MORDIDA_MINK := 3.0
var _mink_bite_cooldown := 0.0
const RECARGA_QUEDA_ESMAGADORA := 3.0
var _air_slam_active := false
var _air_slam_cooldown := 0.0
## ASAS DE ANJO — o golpe exclusivo do Skypean. Ver `src/player/asas_de_anjo.gd`.
var _asas_ativas := false
var _asas_recarga := 0.0
var _asas_t := 0.0
var _asas_rumo := Vector3.ZERO
## ⚠️ É ELE QUE DECIDE A RECARGA. O dono pediu que errar NÃO cobre recarga, então
## o custo só é debitado se a hitbox conectar — ver `_encerrar_asas_de_anjo`.
var _asas_acertou := false
var _asas_zona: DamageZone = null

var _spin_kick_active := false
var _spin_kick_angle := 0.0
var _spin_kick_rest_position := Vector3.ZERO
var _spin_kick_yaw := 0.0
const RECARGA_CHUTE_GIRATORIO := 5.0
var _spin_kick_cooldown := 0.0
# Ataques W/A/S/D compartilham o relógio do MeleeController. Estes campos são
# apenas a apresentação e a base congelada, inclusive nas cópias remotas.
var _contextual_attack_id := ""
var _contextual_attack_yaw := 0.0
var _contextual_presentation_token := 0
# Sequência monotônica do dono. Ela separa duas cotoveladas iguais em rede e
# permite que confirmação, rejeição e cancelamento atinjam somente o golpe que
# lhes deu origem — nunca uma ação posterior que reutilizou o mesmo ID.
var _contextual_attack_seq := 0
var _contextual_presented_seq := -1
# O servidor não lê teclado remoto; em vez disso valida enum, arma, chão,
# origem e cadência. A sequência e o token também impedem RPC repetido e timers
# de hitbox que sobreviveram a dano, dash-cancel ou respawn.
var _server_contextual_next_ms := 0
var _server_contextual_last_seq := -1
var _server_contextual_active_seq := -1
var _server_contextual_token := 0
var _server_contextual_deadline_ms := 0
# Após dano real, poderes de fruta aguardam uma janela curta. Estilos e M1
# continuam livres: esta é recuperação da Akuma no Mi, não um stun geral.
const TRAVA_FRUTA_APOS_DANO := 1.0
var _fruit_damage_lock_timer := 0.0
var _invisivel := false
var _materiais_antes_da_invisibilidade: Dictionary = {}

# ---- corpo a corpo (botão esquerdo): soco D -> soco E -> chute ----
# Ver src/combat/Melee.gd. `_melee_janela` conta o tempo que ainda resta pra
# encadear; zerou, o próximo clique volta ao primeiro soco.
# O combo vive em src/player/melee_controller.gd (Fase 7).
var _melee := MeleeController.new()

# Qual slot está EM USO agora — "" se nenhum. Usado para congelar a recarga das
# outras técnicas (ver o laço de cooldown no _physics_process).
#
# Cobre as quatro formas de "habilidade em andamento" que o jogo tem:
# segurar para mirar (`_charging`), a rajada Z, o cast já solto mas ainda
# rodando (`is_casting`), e os golpes que travam o movimento por tempo
# (Gatling, Red Hawk, Kurouzu, Black Hole — todos gravam `active_skill`).
func _slot_em_uso() -> String:
	if _charging and _charge_slot != "":
		return _charge_slot
	if _rapid_fire:
		return "Z"
	if has_meta("is_casting") and get_meta("is_casting"):
		var s := str(get_meta("active_skill", ""))
		if s != "":
			return s
	var combat_locked = _fsm and _fsm.state and _fsm.state.name in ESTADOS_TRAVADOS
	if combat_locked:
		return str(get_meta("active_skill", ""))
	return ""

func abort_gatling() -> void:
	if not is_inside_tree():
		return
	var world = get_tree().current_scene
	if world:
		for child in world.get_children():
			if child is GomuGatling and child._caster == self:
				child.abort()

# POSE DE ARMA (braço estendido, mirando): rajada Z, pistola da Yami e agora
# qualquer arma de BRAÇO da Buki. O canhão-corpo (X) fica de fora — lá o modelo
# está escondido, e mandar o rig fazer pose de pistoleiro seria trabalho à toa.
func _pose_de_arma() -> bool:
	return _rapid_fire or _yami_pistol_active or (_buki_weapon != "" and _buki_weapon != "X")

# FONTE ÚNICA das recargas. Virou constante porque o SERVIDOR passou a precisar
# dos mesmos números para barrar o saque repetido da Buki (ver
# `BukiController.servidor_sacar`) — dois lugares com a mesma tabela escrita à
# mão é como o furo de munição infinita nasceu.
# V baixou de 60 para 25 s a pedido do dono (2026-08-12): com 60 s o ultimate
# saía uma vez por rodada de 5 min, e testar a mecânica de Charge-up exigia
# esperar um minuto por tentativa.
const RECARGA_POR_SLOT := {"Z": 5.0, "X": 7.0, "C": 10.0, "V": 25.0}

# ESTILO DE LUTA custa 1 MINUTO em qualquer slot (pedido do dono, 2026-08-12).
# É o preço de não depender de fruta: o estilo está SEMPRE disponível — não
# precisa achar árvore, não se perde na morte, não some quando outro jogador
# pega a fruta antes. Uma recarga própria e cara é o que impede o estilo de ser
# estritamente melhor que a fruta.
# ⚠️ Vale para TODOS os estilos, não só o Tritão — foi assim que o dono pediu
# ("para todos os ataques de skills que não sejam frutas").
const RECARGA_ESTILO := 60.0

## Custo de energia de uma técnica: o perfil do modo manda; sem perfil, a constante da
## arena. Um ponto só, para o custo não virar número solto espalhado pelos controladores.
## F no Modo História: o voo curto da fruta. Trava por capacidade, ficha, energia e
## recarga — as mesmas portas das técnicas, no mesmo lugar. Devolve `true` se decolou.
func pedir_voo_de_fruta() -> bool:
	if not capacidades.can_fly or perfil_de_frutas == null or _voo.ativo():
		return false
	var t := perfil_de_frutas.tecnica("F")
	if t == null or t.comportamento != "voo" or not corpo_livre_para_golpe():
		return false
	if float(_fruit_cooldowns.get("F", 0.0)) > 0.0 or float(energy) + 0.001 < t.custo_de_energia:
		return false
	gastar_energia(t.custo_de_energia)
	_fruit_cooldowns["F"] = recarga_do_cast("F")
	_voo.comecar(_mira_do_voo(), t.duracao)
	return true


## Para onde o foguete do F quer ir: o yaw e o pitch da CÂMERA (o mouse pilota em 3D —
## decisão do dono, 30/09/2026), com o pitch de descanso valendo como voo nivelado. O
## `VooFoguete` limita a inclinação e a curva.
func _mira_do_voo() -> Vector3:
	var inclinacao := _pitch - PITCH_DE_DESCANSO
	return RosaDosVentos.frente(_yaw) * cos(inclinacao) + Vector3.UP * sin(inclinacao)


## O dash usa toda a faixa real da câmera: os extremos são vertical puro para
## cima/baixo, inclusive com limites assimétricos. Não altera o voo nem o Geppo.
func _mira_do_dash() -> Vector3:
	var limite := limites_de_pitch()
	var desvio := _pitch - PITCH_DE_DESCANSO
	var faixa := limite.y - PITCH_DE_DESCANSO if desvio >= 0.0 else PITCH_DE_DESCANSO - limite.x
	var angulo := clampf(desvio / maxf(faixa, 0.01), -1.0, 1.0) * PI * 0.5
	return RosaDosVentos.frente(_yaw) * cos(angulo) + Vector3.UP * sin(angulo)


## A forma de foguete segue o voo — estado DERIVADO, conferido todo quadro: não existe
## caminho em que o corpo fique escondido porque ninguém avisou o fim. Golpe (Z/X/C ou
## clique), dano, morte ou perder a fruta desfazem a forma; o corpo desce pelo pouso suave.
func _sincronizar_forma_de_foguete(delta: float) -> void:
	if _voo.forma_de_foguete() and (esta_atacando() or not corpo_livre_para_golpe() \
			or not capacidades.can_fly or (_rocket != null and _rocket.ocupado())):
		_voo.desfazer_forma()
	var quer := _voo.forma_de_foguete()
	if quer and not is_instance_valid(_forma_de_foguete):
		_forma_de_foguete = FORMA_DE_FOGUETE.new()
		_forma_de_foguete.name = "FormaDeFoguete"
		add_child(_forma_de_foguete)
		_atualizar_visibilidade_corpo()
	elif not quer and is_instance_valid(_forma_de_foguete):
		_forma_de_foguete.encerrar()
		_forma_de_foguete = null
		_atualizar_visibilidade_corpo()
	if is_instance_valid(_forma_de_foguete):
		# Em 1ª pessoa a câmera ficaria DENTRO do casco: lá o foguete não se desenha.
		_forma_de_foguete.visible = _camera == null or not _camera.em_primeira_pessoa()
		_forma_de_foguete.atualizar(delta, velocity, _voo.fase() == "pousando")


func voando() -> bool:
	return _voo.ativo()


func custo_de_energia_do_cast(slot: String) -> float:
	if current_fruit_id == "tori_tori_phoenix" and _phoenix != null and _phoenix.desligando(slot):
		return 0.0 # Reverter e pousar nunca exigem energia.
	# Kit e frutas do Builder (06/10/2026): o custo do Builder é uma fração da energia
	# máxima.
	if KitDoBuilder.e_do_builder(current_fruit_id):
		return KitDoBuilder.custo(slot, KitDoBuilder.BARRA_DA_PREVIA if perfil_de_frutas != null else float(max_energy), current_fruit_id)
	# Fruta da arena refeita no Builder (a Pika, 07/10/2026): na história a economia é a
	# da FICHA da fruta (a fração do Builder dava 0,4 onde a ficha cobra 4 — medido no
	# `test_frutas_na_historia`); na arena, a fração (4,4 % de 4096 = os 180 de sempre).
	# Só a tecla que a ficha TEM: o F do Builder (voo da Pika) não está na ficha e cobra a
	# fração dele (sem isto cobrava os 180 da arena numa barra de 10).
	if perfil_de_frutas != null and perfil_de_frutas.fruta == current_fruit_id and perfil_de_frutas.tem(slot):
		return perfil_de_frutas.custo_de_energia(slot, ENERGY_SKILL) * _fator_de_custo_fora_do_mod()
	if KitDoBuilder.pelo_builder(current_fruit_id, slot):
		return KitDoBuilder.custo(slot, KitDoBuilder.BARRA_DA_PREVIA if perfil_de_frutas != null else float(max_energy), current_fruit_id)
	return ENERGY_SKILL


## Custos de energia que NÃO são o da técnica (bala da rajada, dreno por segundo): na
## arena, o número de sempre; com ficha (Modo História), na MESMA proporção do custo da
## técnica Z — a ficha cobra 2 onde a arena cobra 180 (03/10/2026).
func energia_do_modo(valor_da_arena: float) -> float:
	if perfil_de_frutas != null and perfil_de_frutas.fruta == current_fruit_id:
		return valor_da_arena * perfil_de_frutas.custo_de_energia("Z", ENERGY_SKILL) / ENERGY_SKILL * _fator_de_custo_fora_do_mod()
	return valor_da_arena


## A proporção de custo das frutas que não são do mod com a energia do mod (1 fora da história e nas do mod).
func _fator_de_custo_fora_do_mod() -> float:
	if perfil_de_frutas == null or perfil_de_frutas.fiel_ao_mod or not has_meta("nivel_historia"):
		return 1.0
	return preload("res://src/historia/atributos_mine_piece.gd").fator_de_custo_fora_do_mod(int(get_meta("nivel_historia")))


## Dreno da invisibilidade da Suke. Na história a regeneração (1/s) venceria o dreno
## proporcional e a camuflagem nunca acabaria: soma-se a regeneração do modo, e ela
## dura ~16 s com a energia cheia (na arena, ~2 min com a regeneração de lá).
func dreno_da_invisibilidade() -> float:
	return energia_do_modo(ENERGIA_INVISIBILIDADE_POR_SEG) + _vida.regen_energia_do_modo


## Escala do dano das técnicas de `fruta` NESTE modo: 1 na arena; no Modo História,
## a do perfil (o kit da arena na escala da história — `PerfilDeFrutas.da_arena`).
func escala_de_dano_da_fruta(fruta: String, tecnica := true) -> float:
	if perfil_de_frutas != null and perfil_de_frutas.fruta == fruta:
		# Modo História (23/10/2026): técnicas +50 %, soco −50 % (`Balance.HISTORIA_*`).
		if perfil_de_frutas.fiel_ao_mod:
			return perfil_de_frutas.escala_de_dano
		return perfil_de_frutas.escala_das_tecnicas() if tecnica \
			else perfil_de_frutas.escala_de_dano * Balance.HISTORIA_SOCO
	return 1.0


## Recarga de uma técnica, pela mesma regra do custo.
func recarga_do_cast(slot: String) -> float:
	if KitDoBuilder.pelo_builder(current_fruit_id, slot):
		return KitDoBuilder.recarga(slot, current_fruit_id)
	var padrao := SkillSystem.get_slot_cooldown(slot, current_fruit_id)
	if perfil_de_frutas != null and perfil_de_frutas.fruta == current_fruit_id:
		return perfil_de_frutas.recarga(slot, padrao)
	return padrao


func trigger_skill_cooldown(slot: String) -> void:
	if combat_mode == "fruit" and current_fruit_id != "":
		armar_intervalo_de_golpe(slot)
	# Kit do Builder: a recarga da skill, também na tecla F (fora de RECARGA_POR_SLOT).
	if combat_mode == "fruit" and KitDoBuilder.pelo_builder(current_fruit_id, slot):
		_fruit_cooldowns[slot] = recarga_do_cast(slot)
		return
	if combat_mode == "fruit" and current_fruit_id in ["ope_ope", "bara_bara", "rocket", "tori_tori_phoenix"]:
		_fruit_cooldowns[slot] = recarga_do_cast(slot)
		return # a janela de compromisso é a animação da técnica
	if not RECARGA_POR_SLOT.has(slot):
		return
	if combat_mode == "style":
		_style_cooldowns[slot] = RECARGA_ESTILO
	else:
		if current_fruit_id == "":
			_fruit_cooldowns[slot] = 0.0
		elif perfil_de_frutas != null and perfil_de_frutas.fruta == current_fruit_id:
			# Modo História (fruta da arena vendida no vendedor): a ficha manda — é o
			# número que o menu de técnicas mostra (03/10/2026).
			_fruit_cooldowns[slot] = recarga_do_cast(slot)
		elif current_fruit_id == "bomu_bomu" or current_fruit_id == "suke_suke":
			_fruit_cooldowns[slot] = 10.0
		else:
			_fruit_cooldowns[slot] = RECARGA_POR_SLOT[slot]
		# Qualquer ataque de fruta arma a trava — inclusive os de recarga curta.
		_trava_pos_fruta = TRAVA_POS_FRUTA
var _mesh: MeshInstance3D
var _crosshair: Control

## O golpe de fruta da tecla saiu: o próximo só daqui a `INTERVALO_ENTRE_GOLPES` (ou o
## intervalo da skill do Builder). Chamado de novo quando "Carregar e soltar" dispara.
func armar_intervalo_de_golpe(slot: String) -> void:
	var s := INTERVALO_ENTRE_GOLPES
	if KitDoBuilder.pelo_builder(current_fruit_id, slot):
		s = KitDoBuilder.intervalo_depois(slot, current_fruit_id)
	_intervalo_golpe = maxf(_intervalo_golpe, s)


# ELENCO TRANCADO: só o "base" (decisão do usuário) — é nele que a animação está
# sendo feita. Os outros modelos continuam no projeto, mas não são selecionáveis:
# ver CHARS_TRANCADOS em src/ui/CharacterMenu.gd.
const ELENCO_LIBERADO: Array[String] = ["base", "bluebuddy"]

# ---- RIG E MODELO -> src/player/player_rig.gd (Fase 3) ----
# O componente é dono do CICLO DE VIDA do corpo visível (criar, medir, vestir,
# soltar). O que segue abaixo são VISTAS: propriedades só-leitura que encaminham
# para o rig.
#
# Por que vistas e não simplesmente `_rig.modelo()` em todo canto: `_char_model`
# é lido em ~42 pontos aqui dentro, e o `BukiFX.gd` o pega de fora por nome
# (`caster.get("_char_model")`). Getter mantém UM dono (o rig) e zero estado
# duplicado, sem precisar reescrever nada disso. Escrever nesses campos era o
# que o relatório chamava de conflito — e agora é impossível: não têm setter.
var _rig: PlayerRig = null
var _yoru_combat: Node = null
var _yoru_network: Node = null

var character_id: String:
	get: return _rig.character_id if _rig else "base"
var _animator: CharacterAnimator:
	get: return _rig.animador() if _rig else null
var _char_model: Node3D:
	get: return _rig.modelo() if _rig else null
var _proc_anim: ProceduralAnimator:   # animação procedural em tempo real do rig
	get: return _rig.procedural() if _rig else null
var _skel_anim: SkeletalAnimator:     # animador ESQUELETAL (personagens skinnados)
	get: return _rig.esqueletal() if _rig else null
var _is_skinned: bool:                # o personagem atual é skinnado (Skeleton3D)?
	get: return _rig.skinnado() if _rig else false
var _head_node: Node3D:               # cabeça do modelo atual (âncora do fôlego)
	get: return _rig.cabeca() if _rig else null
var _breath = null                   # VFX de fôlego (instância de VFX/BreathVFX.tscn; sem tipo p/ não depender do cache de class_name)

# ---- Rede (Fase 4) ----
# _is_authority = este player é controlado por ESTE cliente (input+câmera). No
# singleplayer o host é a autoridade -> tudo funciona igual. Players remotos só
# reproduzem a pose a partir do estado replicado (net_velocity/net_facing).
var _is_authority: bool = true

## QUEM É "O MEU JOGADOR" NESTA TELA.
##
## O grupo "player" tem TODOS os corpos (é assim que o Placar, a DamageZone e os
## FX varrem a partida). Quem quer o corpo DESTE peer — HUD, barras, menus —
## precisa filtrar pela autoridade: `get_first_node_in_group("player")` devolve o
## PRIMEIRO da árvore, que no cliente é o corpo do HOST (ele nasceu antes).
##
## Era exatamente esse o bug: no cliente a HUD lia energia e mandava as teclas
## Z/X/C/V no corpo do host — um corpo sem autoridade, que não regenera energia
## (a regen do `_physics_process` só roda na autoridade) e engole todo pedido de skill
## (`_request_cast` corta em `not _is_authority`). No host o primeiro da árvore
## É o corpo dele, e por isso o bug NUNCA apareceu de quem hospeda.
static func local_player(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var todos := tree.get_nodes_in_group("player")
	for p in todos:
		if p.is_multiplayer_authority():
			return p
	# Sem autoridade nenhuma (corpo ainda não spawnado): melhor nada que o errado.
	return null

var _hitstop_timer: float = 0.0

@export var net_velocity: Vector3 = Vector3.ZERO   # replicado (autoridade -> demais)
@export var net_facing: float = 0.0
@export var net_on_floor: bool = true
# Estado visual de cargas que precisam aparecer antes do impacto. São somente
# apresentação: o servidor continua sendo a autoridade que cria o golpe final.
@export var net_charge_pose: String = ""
@export var net_charge_progress: float = 0.0
# Parkour e locomoção (fatia 4 de docs/PARKOUR_MIRRORS_EDGE_PLANO.md, 03/10/2026):
# o que os outros precisam para VER o wall run, a escalada e a inclinação de curva.
# Só apresentação — a física é de quem tem autoridade.
@export var net_parkour: String = ""          # token de pose ("wall_run", "borda", "roll"…)
@export var net_agachado: bool = false
@export var net_escalando: bool = false       # na escada (pose de escalada)
@export var net_parede_lado: int = 0          # wall run: +1 parede à direita, −1 à esquerda
@export var net_subida: float = 0.0           # 0..1 subindo a borda
@export var net_inclinacao: Vector2 = Vector2.ZERO   # (lateral, frente) da locomoção
@export var net_acao_clipe: String = ""       # clipe de ação (roll, deslize) — "" = nenhum
@export var net_acao_tempo: float = 0.0       # tempo desse clipe neste quadro
var _parkour_anim := ""                       # o token que o animador recebeu neste quadro

func _ready() -> void:
	add_to_group("player")
	# Autoridade = eu sou dono desse player (mesmo em singleplayer, id 1 é meu)
	_is_authority = is_multiplayer_authority()
	print("[Player] _ready! name=", name, " authority=", get_multiplayer_authority(), " is_auth=", _is_authority, " peer=", multiplayer.get_unique_id())   # SP: host=autoridade -> true

	# RIG E MODELO — componente próprio desde a Fase 3. Precisa existir ANTES do
	# set_character, que é justamente quem manda o rig montar o corpo.
	_rig = PlayerRig.new()
	_rig.name = "PlayerRig"
	add_child(_rig)
	_rig.montar_em(self)
	_dash.montar_em(self)
	_dash_ar.montar_em(self)
	_voo.montar_em(self)
	_phoenix = preload("res://src/player/phoenix_controller.gd").new()
	_phoenix.name = "Phoenix"
	add_child(_phoenix)

	_fsm = PlayerStateMachine.new()
	_fsm.name = "CombatFSM"
	_fsm.set_physics_process(false)
	
	# ⚠️ O NOME DO NÓ É O ENDEREÇO. `PlayerStateMachine.transition_to` resolve por
	# `has_node(nome)` e faz `return` calado quando não acha — foi assim que
	# "Stunned" ficou sendo pedido em sete pontos do arquivo sem nunca existir
	# (ver o cabeçalho de `CombatStateStunned.gd`). Estado novo entra AQUI, ou
	# ele não entra em lugar nenhum.
	var state_idle = CombatStateIdle.new()
	state_idle.name = "Idle"
	_fsm.add_child(state_idle)

	# As TRÊS fases do golpe (§4.1 do PLANO_COMBATE_BATTLEGROUNDS). Substituem o
	# antigo "Attacking", que não distinguia preparar de estar preso no rabo do
	# golpe — e era nessa diferença que morava o contra-jogo inteiro.
	var state_startup = CombatStateAttackStartup.new()
	state_startup.name = "AttackStartup"
	_fsm.add_child(state_startup)

	var state_active = CombatStateAttackActive.new()
	state_active.name = "AttackActive"
	_fsm.add_child(state_active)

	var state_recovery = CombatStateAttackRecovery.new()
	state_recovery.name = "AttackRecovery"
	_fsm.add_child(state_recovery)

	var state_stunned = CombatStateStunned.new()
	state_stunned.name = "Stunned"
	_fsm.add_child(state_stunned)

	var state_dashing = CombatStateDashing.new()
	state_dashing.name = "Dashing"
	_fsm.add_child(state_dashing)
	
	add_child(_fsm)
	_fsm.init(self, state_idle.get_path())
	_buki.montar_em(self, _rig)
	_disparo.montar_em(self)
	_poeira_dos_pes.montar_em(self)
	_corpo_de_ferro.montar_em(self)
	_cast.montar_em(self)
	_melee.montar_em(self)
	_rocket = preload("res://src/combat/rocket_controller.gd").new()
	_rocket.name = "RocketController"
	add_child(_rocket)
	_vida.montar_em(self)
	_mira.montar_em(self)
	_parkour.montar_em(self, GRAVITY, JUMP_VELOCITY)
	_loco_chao.rumo = rotation.y

	# Substitui o quadrado cinza pelo modelo 3D Voxel e equipa a Akuma no Mi correspondente
	set_character(character_id)
	var ope_weapon := preload("res://src/player/OpeWeapon.gd").new()
	ope_weapon.setup(self)
	add_child(ope_weapon)

	# Colisor do jogador: caixa na arena, cápsula no Modo História (ver `colisor_capsula`).
	var col := CollisionShape3D.new()
	if colisor_capsula:
		var capsula := CapsuleShape3D.new()
		capsula.radius = RAIO_DA_CAPSULA
		capsula.height = COLISOR_BASE.y
		col.shape = capsula
		# O combate continua acertando a CAIXA de antes (golpes afinados contra ela):
		# hurtbox separada, que não interfere no movimento (ver HurtboxDeCombate).
		HurtboxDeCombate.instalar(self, COLISOR_BASE)
	else:
		var shape := BoxShape3D.new()
		shape.size = COLISOR_BASE
		col.shape = shape
	add_child(col)
	_colisor = col
	_agachar.montar(self, col)

	# CÂMERA — componente próprio desde a Fase 2. Ele monta a cadeia
	# (pivô → ombro → SpringArm → Camera3D) e é dono de tremor, FOV e balanço.
	# O `_cam` fica guardado aqui só porque a mira o consulta em 26 lugares.
	_camera = CameraRig.new()
	_camera.name = "CameraRig"
	add_child(_camera)
	_camera.montar(self, _is_authority)
	_cam = _camera.camera()
	# O rig é montado ANTES do colisor e da câmera (a aplicação da escala do corpo no `montar` não os achou): o fator do modo (Modo História, 19/11/2026)
	# tem de chegar à cápsula, à hurtbox e à câmera também — os três ou nenhum.
	if not is_equal_approx(escala_de_modo, 1.0):
		_aplicar_escala_de_raca()

	# Gear 2: a primeira TRANSFORMAÇÃO. Componente próprio porque tem estado com
	# entrada, duração e quatro saídas distintas (relógio, morte, troca de fruta,
	# troca de personagem) — ver o cabeçalho de `gear2_controller.gd`.
	_gear2 = Gear2Controller.new()
	_gear2.name = "Gear2"
	add_child(_gear2)
	_gear2.montar(self, _rig)

	# Mira + captura de mouse SÓ para o player local (players remotos não têm HUD/mira).
	if _is_authority:
		var layer := CanvasLayer.new()
		add_child(layer)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(center)
		var dot := Label.new()
		dot.text = "+"
		dot.add_theme_font_size_override("font_size", 24)
		center.add_child(dot)
		_crosshair = center
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_apply_perspective()
	_update_pivot()
	# Montado em TODAS as cópias, depois do rig e dos controladores de estado.
	var yoru_script = load("res://src/combat/YoruController.gd") if ResourceLoader.exists("res://src/combat/YoruController.gd") else null
	if yoru_script:
		_yoru_combat = yoru_script.new()
		_yoru_combat.name = "YoruCombat"
		add_child(_yoru_combat)
		_yoru_combat.setup(self)
	_yoru_network = load("res://src/player/YoruNetwork.gd").new()
	_yoru_network.name = "YoruNetwork"
	add_child(_yoru_network)
	_yoru_network.setup(self, _yoru_combat)

## Até onde a mira sobe e desce (radianos; x = para baixo, y = para cima). Com o clique de blocos nas mãos vai quase à vertical, como no Minecraft:
## é o que permite quebrar o bloco SOB os pés e o de CIMA da cabeça. Fora disso, −1,2 / 1,25 (≈ −69° / +72°).
const PITCH_DE_BLOCOS := Vector2(-1.5, 1.5)
func limites_de_pitch() -> Vector2:
	if clique_de_blocos != null and clique_de_blocos.assume_as_maos():
		return PITCH_DE_BLOCOS
	return Vector2(-1.2, 1.25)          # olhar mais para CIMA (12/11/2026: era 0,5 rad = 29°; agora ~72°) — o tronco acompanha (`ProceduralAnimator._lookat`)


## O rig da câmera (para a mira do clique de blocos: de frente a câmera olha PARA o personagem, e a mira é `direcao_da_mira()`).
func rig_da_camera() -> CameraRig:
	return _camera


func _apply_perspective() -> void:
	if _camera:
		_camera.aplicar_perspectiva()
	_atualizar_visibilidade_corpo()   # some o corpo na 1ª pessoa (e no canhão da Buki)

func _input(event: InputEvent) -> void:
	if not _is_authority:
		return
	# ⚠️ NO TOQUE NÃO EXISTE MOUSE CAPTURADO. O `ToqueHud` traduz o arrasto do
	# dedo em `InputEventMouseMotion` para reaproveitar exatamente esta rotina —
	# mas `MOUSE_MODE_CAPTURED` nunca é verdade num celular, e sem esta segunda
	# condição a câmera simplesmente não giraria lá.
	if event is InputEventMouseMotion \
			and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or ToqueHud.ativo()):
		# LUNETA DA SNIPER: com o zoom ligado a mira anda mais devagar. Sem isso o
		# zoom só aumenta a imagem e piora a pontaria (o mesmo movimento de mouse
		# varre 3x mais mundo).
		var fluxo := get_node_or_null("/root/GameFlow")
		var sens := MOUSE_SENS * (float(fluxo.get("sensibilidade")) if fluxo != null else 1.0) * (0.38 if _buki_scope else 1.0)
		_yaw -= event.relative.x * sens
		var lim := limites_de_pitch()
		_pitch = clamp(_pitch - event.relative.y * sens, lim.x, lim.y)
		_update_pivot()
	elif event is InputEventMouseButton and _camera and not _camera.em_primeira_pessoa() and not zoom_por_teclas:
		# Menu aberto (M, N, B, loja...): a roda rola a lista, e não aproxima a câmera.
		# (`zoom_por_teclas`: no Modo História a roda é da hotbar e o zoom é I/O.)
		if _menu_de_tela_aberto():
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_camera.ajustar_distancia(-0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_camera.ajustar_distancia(0.5)

## Algum menu da HUD (história ou arena) está aberto? A câmera não deve reagir à roda.
func _menu_de_tela_aberto() -> bool:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	return hud != null and hud.has_method("is_menu_open") and hud.is_menu_open()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_authority:
		return
	if esta_capturado_pelo_vento():
		return
	# ARENA, Kit do Builder com skill no F (06/10/2026): o F é dela, e não do Corpo de
	# Ferro. Na história quem roteia o F é a `HistoriaHud` (lá `can_use_skills` é falso).
	# 07/10/2026: também a fruta da arena refeita com skill no F (o voo da Pika).
	if event is InputEventKey and not event.echo and event.keycode == KEY_F \
			and capacidades.can_use_skills and combat_mode == "fruit" \
			and (KitDoBuilder.pelo_builder(current_fruit_id, "F") or current_fruit_id == "tori_tori_phoenix"):
		if event.pressed:
			begin_charge("F")
		else:
			release_charge("F")
		get_viewport().set_input_as_handled()
		return
		
	# Se clicar na tela com o mouse solto (ex: após alt-tab), recaptura ele.
	# Menus abertos consomem o input antes, então isso só roda no jogo limpo.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return

	# Modo História: clique e direção do combate direcional. Ponte EXPLÍCITA (e não
	# ordem de propagação de input) para que entregar o evento ao Player — como os
	# testes fazem — passe pelo mesmo caminho do jogo.
	# O clique do Minecraft vem ANTES: com as mãos dele, o mouse não vira soco nem guarda (a guarda cede o botão direito).
	if clique_de_blocos != null and clique_de_blocos.tratar(event):
		return
	if entrada_combate_direcional != null and entrada_combate_direcional.tratar(event):
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		# Alterna 1a <-> 3a pessoa.
		if _camera:
			_camera.alternar_perspectiva()
		_apply_perspective()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		# Cicla o modelo — hoje o elenco está trancado no "base", então F6 não
		# tem para onde ir. Liberar outro personagem é só acrescentar em
		# ELENCO_LIBERADO.
		if ELENCO_LIBERADO.size() > 1:
			var idx := ELENCO_LIBERADO.find(character_id)
			set_character(ELENCO_LIBERADO[(idx + 1) % ELENCO_LIBERADO.size()])
		else:
			print("[Personagem] elenco trancado em: ", ELENCO_LIBERADO[0])
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_1, KEY_2, KEY_3] and capacidades.can_use_skills:
		# 1/2/3 escolhem o modo de combate (2026-09-06, pedido do dono). Antes
		# era o R alternando entre dois; a espada virou o terceiro e alternar
		# deixou de servir. Escolher QUAL fruta/estilo continua no menu do M.
		set_combat_mode({KEY_1: "fruit", KEY_2: "style", KEY_3: "sword"}[event.keycode])
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T \
			and capacidades.can_use_skills:
		_cycle_fruit()   # DEBUG: cicla entre as frutas pra testar as skills
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E \
			and capacidades.can_use_skills and not _e_e_do_inventario():
		aim_assist = not aim_assist   # liga/desliga a assistência de mira
		# 2026-08-22: o E deixou de ser só assistência de mira. Com ele ligado, os
		# corpos e os ATAQUES EM VOO dos outros passam a ser desenhados através das
		# paredes (`ScreenFX`: `no_depth_test` no material de destaque).
		print("👁️ Observação (alvos e preparações através de paredes): ",
			"LIGADA" if aim_assist else "DESLIGADA")
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("set_aim_assist"):
			hud.set_aim_assist(aim_assist)
		if Engine.has_singleton("ScreenFX") or get_node_or_null("/root/ScreenFX"):
			get_node("/root/ScreenFX").set_aim_assist(aim_assist, self)
	# Teclas de técnica/combate: sem a capacidade o `elif` não casa e a tecla
	# simplesmente não faz nada (as teclas abaixo são outras, não há desvio).
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G \
			and capacidades.can_attack:
		_request_combo_breaker()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F \
			and capacidades.can_use_skills:
		_pedir_corpo_de_ferro()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not event.echo:
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("toggle_main_menu"):
				hud.toggle_main_menu()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# Com arma na mão o botão direito é MIRA (auxílio da Buki / luneta da
		# sniper / mira da Yami), não doma.
		if not _yami_pistol_active and _buki_weapon == "":
			_try_tame()   # Fase 8: botão direito DOMA o inimigo mirado
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Corpo a corpo. A pistola da Yami e as armas da Buki também usam o botão
		# esquerdo (têm tratamento próprio em `DisparoSustentado` /
		# `BukiController.atualizar`) — quem está de arma na mão atira, não soca.
		if not _yami_pistol_active and _buki_weapon == "":
			_request_melee()

## Seleção DIRETA de modo, pelas teclas 1/2/3.
##
## Substituiu o `toggle_combat_mode` do R, que foi REMOVIDO junto (não sobrou
## chamador: conferido em .gd e .tscn). Alternar só sabia ir e voltar entre dois
## — com três modos exigiria saber em qual você está para prever onde vai parar,
## e o dono pediu seleção direta justamente por isso.
func set_combat_mode(modo: String) -> void:
	if _yoru_network:
		_yoru_network.request_mode(modo)
	elif _is_authority:
		_apply_combat_mode(modo)


func _apply_combat_mode(modo: String) -> void:
	if modo == combat_mode:
		return
	if not modo in ["fruit", "style", "sword"]:
		return
	_cancel_yoru_action("mode")
	_cast.abortar()
	_melee.cancelar_golpe()
	# Sair do modo fruta com arma da Buki na mão faz a arma cair, como sempre.
	_buki_guardar()
	_buki_mostrar_arma("")

	# A espada é a única que tem presença física: entrar no modo 3 a saca, sair
	# a guarda. `_yoru` é a fonte da verdade, então basta pedir o estado certo.
	var quer_espada := modo == "sword"
	if quer_espada != (_yoru != null and is_instance_valid(_yoru)):
		_toggle_yoru_visual()

	combat_mode = modo
	var active_style: String = STYLES_LIST[current_style_idx]
	print("⚔️ Modo de combate: %s%s" % [combat_mode.to_upper(),
		(" - Estilo: " + active_style) if combat_mode == "style" else ""])
	var hud := get_tree().get_first_node_in_group("hud")
	if _is_authority and hud and hud.has_method("update_combat_mode"):
		hud.update_combat_mode(combat_mode, active_style, current_fruit_id)


## Portão do cast de frutas/estilos; a espada tem técnicas próprias.
func pode_conjurar() -> bool:
	return combat_mode != "sword" and not esta_capturado_pelo_vento()


func set_fighting_style(style_id: String) -> void:
	var idx := STYLES_LIST.find(style_id)
	if idx >= 0:
		current_style_idx = idx
		var active_style: String = STYLES_LIST[current_style_idx]
		print("🥋 Novo Estilo de Luta Selecionado (Menu M): ", active_style)
		# ⚠️ PASSA PELO CAMINHO ÚNICO. Isto atribuía `combat_mode = "style"` na
		# mão, o que era inofensivo enquanto só existiam dois modos — agora
		# deixaria a Yoru NA MÃO com a barra de estilo na tela, porque quem
		# guarda a espada é o `set_combat_mode`. Escolher um estilo no menu do M
		# passa a valer como apertar o 2.
		if combat_mode != "style":
			set_combat_mode("style")
		else:
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("update_combat_mode"):
				hud.update_combat_mode(combat_mode, active_style, current_fruit_id)

# Toca um clipe de ESTILO retargetado (Mixamo -> rig por-nós) pelo ProceduralAnimator.
# O clipe fica em res://assets/animations/<nome>.res (bakeado do FBX do Mixamo).
func play_style_anim(anim_name: String) -> void:
	if _proc_anim == null:
		return
	var previous_studio := get_node_or_null("StudioPlayback")
	if previous_studio:
		previous_studio.finish()
		remove_child(previous_studio)
	var studio_path := "res://assets/animations/%s.tres" % anim_name
	if ResourceLoader.exists(studio_path):
		var studio_clip = ResourceLoader.load(studio_path, "Animation", ResourceLoader.CACHE_MODE_IGNORE)
		if studio_clip is Animation and studio_clip.has_meta("studio_version"):
			if preload("res://src/anim/StudioPlayback.gd").play(self, studio_clip):
				lock_movement(studio_clip.length + 0.1, anim_name)
				return
	# .res = assado do Mixamo (binário). .tres = autorado no editor de animação
	# em Python (texto) — o Godot carrega os dois igual.
	var path := "res://assets/animations/%s.res" % anim_name
	if not ResourceLoader.exists(path):
		path = "res://assets/animations/%s.tres" % anim_name
	if not ResourceLoader.exists(path):
		print("[StyleAnim] animação não encontrada: ", anim_name,
			" (.res vem do baker do Mixamo, .tres do tools/anim_editor)")
		return
	var a = load(path)
	if a is Animation:
		_proc_anim.play_baked(a)
		lock_movement(a.length + 0.1, anim_name)

# --- Teste de Animação: cicla por TODOS os .res bakeados (Mixamo) ---
var _style_anims: Array = []
var _style_anim_idx: int = -1

func _scan_style_anims() -> void:
	_style_anims.clear()
	var d := DirAccess.open("res://assets/animations/")
	if d:
		for f in d.get_files():
			var b := f.to_lower()
			# .res vem do baker do Mixamo; .tres, do editor em Python
			if (b.ends_with(".res") or b.ends_with(".tres")) and not _style_anims.has(f.get_basename()):
				_style_anims.append(f.get_basename())
	_style_anims.sort()

func cycle_style_anim(dir: int) -> void:
	if _style_anims.is_empty():
		_scan_style_anims()
	if _style_anims.is_empty():
		return
	if _style_anim_idx < 0:
		_style_anim_idx = 0
	else:
		_style_anim_idx = wrapi(_style_anim_idx + dir, 0, _style_anims.size())
	var nm: String = _style_anims[_style_anim_idx]
	play_style_anim(nm)
	print("🎬 [", _style_anim_idx + 1, "/", _style_anims.size(), "] ", nm)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_anim_name"):
		hud.show_anim_name("%d/%d  %s" % [_style_anim_idx + 1, _style_anims.size(), nm])

func _update_pivot() -> void:
	if _camera:
		_camera.apontar(_yaw, _pitch)

# ---- Camera Feel: screen-shake (h_offset/v_offset NÃO afetam a mira) ----
# Tremor de tela. Continua aqui porque MUITA gente de fora chama (efeitos das
# frutas, corpo a corpo, pouso) — o Player repassa ao rig em vez de expor o
# componente inteiro.
# ------------------------------------------------------- PEDIDO DO CORPO A CORPO
# O golpe tem que NASCER NO SERVIDOR: a `DamageZone` só machuca lá.
func pedir_golpe_no_servidor(passo: int, origem: Vector3, fwd: Vector3) -> void:
	if equipped_weapon == "sword":
		request_yoru_action("M1")
		return
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_melee(passo, origem, fwd)
	else:
		_net_melee.rpc_id(1, passo, origem, fwd)

# ------------------------------------------------------------ PEDIDOS DO CAST
# `CastController` (passo 6c) decide SE e COMO conjurar; o que é do Player
# continua do Player.

# A mira do cast: raio da câmera até o mundo, e a origem à frente do corpo.
# Fica aqui porque depende da câmera e do corpo — os dois são do Player.
func mira_do_cast() -> Dictionary:
	var frente := -_cam.global_transform.basis.z
	var origem := global_position + Vector3.UP * 1.0 + frente * 1.5
	var espaco := get_world_3d().direct_space_state
	var de := _cam.global_position
	var ate := de + frente * 150.0
	var par := PhysicsRayQueryParameters3D.create(de, ate)
	par.exclude = [get_rid()]
	# Ignora as HURTBOXES do combate da história (camada própria): a do PRÓPRIO jogador
	# é outro corpo, e com o corpo grande da Gura (escala 2) a câmera alta enxergava
	# através dela — o retículo "acertava" o próprio jogador e todo golpe saía torto
	# (medido em 05/10/2026). O alvo continua sendo achado pelo corpo dele.
	par.collision_mask = ~HurtboxDeCombate.CAMADA & 0xFFFFFFFF
	# Ignora ÁREAS (triggers e a própria DamageZone) para a mira não bater no ar.
	par.collide_with_areas = false
	par.collide_with_bodies = true
	var hit := espaco.intersect_ray(par)
	var ponto: Vector3 = hit.position if not hit.is_empty() else ate
	return {"aim": (ponto - origem).normalized(), "origem": origem}

# Host/SP JÁ é o servidor -> executa a autoridade DIRETO (`rpc_id` a si mesmo é
# proibido pelo Godot). Cliente puro -> pede ao servidor (peer 1).
func pedir_cast_no_servidor(slot: String, aim: Vector3, origem: Vector3,
		charge: float = 0.0, cast_token: int = 0) -> void:
	# A fonte viaja como snapshot junto do golpe. Confiar no `combat_mode` da
	# copia receptora criava uma corrida real: o RPC podia chegar antes da
	# replicacao da troca para Pacifista e o servidor executava a fruta anterior.
	var source_kind := combat_mode
	var source_id := estilo_atual() if source_kind == "style" else current_fruit_id
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_cast(slot, aim, origem, charge, cast_token, source_kind, source_id)
	else:
		_net_cast.rpc_id(1, slot, aim, origem, charge, cast_token, source_kind, source_id)

func pedir_iniciar_hold(slot: String, fruit: String) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_net_start_hold(slot, fruit)
	else:
		_net_start_hold.rpc_id(1, slot, fruit)

@rpc("any_peer", "call_local", "reliable")
func _net_start_hold(slot: String, fruit: String) -> void:
	var cid = multiplayer.get_remote_sender_id()
	if cid != 0 and cid != get_multiplayer_authority() and multiplayer.is_server():
		return
	if fruit == "yami_yami":
		if slot == "C":
			set_meta("yami_black_hole_active", true)
		elif slot == "X":
			set_meta("yami_kurouzu_active", true)
	elif fruit == "pika_pika" and slot == "C":
		set_meta("pika_c_active", true)

func pedir_cancelar_hold(slot: String, fruit: String, cast_token: int = 0,
		forcado: bool = false) -> void:
	if not multiplayer.has_multiplayer_peer():
		_net_cancel_hold(slot, fruit, cast_token, forcado)
	elif multiplayer.is_server():
		_retransmitir_cancel_hold(slot, fruit, cast_token, forcado)
	else:
		# O cliente fala APENAS com o servidor. Ele valida o remetente e vira a
		# fonte unica que ordena START e CANCEL para todos os observadores.
		_net_request_cancel_hold.rpc_id(1, slot, fruit, cast_token, forcado)


@rpc("any_peer", "call_remote", "reliable")
func _net_request_cancel_hold(slot: String, fruit: String, cast_token: int,
		forcado: bool) -> void:
	if not multiplayer.is_server():
		return
	var cid := multiplayer.get_remote_sender_id()
	if cid != get_multiplayer_authority():
		return
	_retransmitir_cancel_hold(slot, fruit, cast_token, forcado)


func _retransmitir_cancel_hold(slot: String, fruit: String, cast_token: int,
		forcado: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		_net_apply_cancel_hold.rpc(slot, fruit, cast_token, forcado)
	else:
		_net_cancel_hold(slot, fruit, cast_token, forcado)


@rpc("any_peer", "call_local", "reliable")
func _net_apply_cancel_hold(slot: String, fruit: String, cast_token: int,
		forcado: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		var cid := multiplayer.get_remote_sender_id()
		if cid != 0 and cid != 1:
			return
	_net_cancel_hold(slot, fruit, cast_token, forcado)


## Aplicacao local separada do transporte para ser testavel sem dois processos.
## O token impede um key-up antigo de apagar uma nova sustentacao do mesmo slot.
func _net_cancel_hold(slot: String, fruit: String, cast_token: int = 0,
		forcado: bool = false) -> void:
	# O campo se chama `fruit` por idade, mas o que ele carrega é a ORIGEM do
	# hold: o Pacifista é um estilo e usa este mesmo canal para apagar o feixe.
	if fruit == "pacifista":
		var token_atual := int(get_meta("px_token_%s" % slot, 0))
		if cast_token > 0 and token_atual > 0 and cast_token < token_atual:
			return
		if cast_token > 0:
			set_meta("px_cancel_token_%s" % slot,
				maxi(cast_token, int(get_meta("px_cancel_token_%s" % slot, 0))))
		match slot:
			"Z": set_meta("px_laser_ativo", false)
			"X": set_meta("px_iron_rush_ativo", false)
			"C": set_meta("px_lance_ativo", false)
			"V": set_meta("px_tri_beam_ativo", false)
		if forcado:
			var cancel_meta: String = str({
				"Z": "px_laser_cancelado",
				"X": "px_iron_rush_cancelado",
				"C": "px_lance_cancelado",
				"V": "px_tri_beam_cancelado",
			}.get(slot, ""))
			if cancel_meta != "":
				set_meta(cancel_meta, true)
		# Z nao tem combo minimo: release encerra imediatamente. Cancelamento
		# forcado (dano/morte) tambem limpa qualquer slot sem esperar o VFX.
		if slot == "Z" or forcado:
			finalizar_skill_pacifista(slot, cast_token)
		return
	if fruit == "yami_yami":
		if slot == "C":
			set_meta("yami_black_hole_active", false)
		elif slot == "X":
			set_meta("yami_kurouzu_active", false)
	elif fruit == "pika_pika" and slot == "C":
		var atual := int(get_meta("pika_c_token", 0))
		if cast_token <= 0 or atual <= 0 or cast_token >= atual:
			set_meta("pika_c_active", false)

# Carregar um golpe PRENDE o corpo no lugar. `velocity` é do domínio de
# movimento — por isso é pedido, não escrita.
func congelar_para_cast() -> void:
	velocity = Vector3.ZERO

# Pausar a animação enquanto mira é apresentação, e o animador é do rig.
func pausar_animacao(pausado: bool) -> void:
	if _animator and _animator.animation_player:
		_animator.animation_player.speed_scale = 0.0 if pausado else 1.0

# Guardar a pistola da Yami some com ela do rig também — o componente de
# disparo não conhece as pistolas (elas são do `PlayerRig`).
func guardar_pistola_da_yami() -> void:
	_disparo.desligar_yami()
	for g in _pistols:
		if is_instance_valid(g):
			g.visible = false

func pedir_soco_de_fov(quantidade: float) -> void:
	if _camera:
		_camera.pedir_fov_punch(quantidade)

func estilo_atual() -> String:
	return STYLES_LIST[current_style_idx] if current_style_idx < STYLES_LIST.size() else ""

# ------------------------------------------------- PEDIDOS DO DISPARO SUSTENTADO
# `DisparoSustentado` (passo 6a) é dono da rajada Z e da pistola da Yami, e não
# escreve estado alheio.

# `energy` é campo de TRÊS domínios (ciclo, skills, respawn) e está reservada
# para a Fase 8 — por isso é pedido, não escrita direta.
func gastar_energia(custo: float) -> void:
	_vida.gastar(custo)

# Bala SEM arma (rajada Z e pistola da Yami). O canal é o mesmo da Buki, e é por
# isso que ele mora aqui: RPC se resolve por CAMINHO DE NÓ.
func pedir_bala_simples(aim: Vector3, origem: Vector3) -> void:
	if not _is_authority or is_suppressed:
		return
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_bullet(aim, origem, "")
	else:
		_net_bullet_req.rpc_id(1, aim, origem, "")

# Aplica uma mira já calculada. Quem decide PARA ONDE olhar é quem tem a arma;
# `_yaw`/`_pitch` continuam sendo do Player (decisão da Fase 2, porque quem os
# escreve é o input). `forca_corpo` existe porque cada arma vira o corpo num
# ritmo diferente — a Yami em 20, a Buki em 14.
func aplicar_mira(novo_yaw: float, novo_pitch: float, delta: float, forca_corpo: float) -> void:
	_yaw = novo_yaw
	_pitch = novo_pitch
	_update_pivot()
	if _char_model:
		# Na parede (wall run) o corpo é da parede: segue a tangente dela.
		if not _parkour.assumiu():
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw, forca_corpo * delta)

# ---------------------------------------------------------- PEDIDOS DA BUKI
# O `BukiController` (Fase 5) é dono do arsenal, mas NÃO escreve estado alheio.
# Estes são os pedidos dele — mesma disciplina do `pedir_shake` (Fase 2) e do
# `pedir_rolamento` (Fase 4).

# RECUO do canhão: o tranco empurra o jogador. O empurrão e a `velocity` são de
# domínio de MOVIMENTO; o arsenal pede, não escreve.
func pedir_recuo(direcao: Vector3, forca: float) -> void:
	_vida.empurrar_cru(direcao, forca)
	velocity.y += forca * 0.32

# Coice visual da arma (1 -> 0), lido pela pose de mira do animador. É
# compartilhado com a rajada Z e a pistola da Yami — por isso continua aqui.
func pedir_coice_de_arma() -> void:
	_gun_recoil = 1.0
	if buki_viewmodel != null and is_instance_valid(buki_viewmodel):
		buki_viewmodel.coice(1.0)

# ---- FPS DA BUKI (22/11/2026): arma na mão = câmera em 1ª pessoa + cópia da arma na frente da tela ----
var buki_viewmodel: BukiViewmodel = null
func buki_fps(sim: bool, slot: String) -> void:
	if not _is_authority or _camera == null:
		return
	_camera.forcar_primeira_pessoa(sim)
	if sim:
		if buki_viewmodel == null or not is_instance_valid(buki_viewmodel):
			buki_viewmodel = BukiViewmodel.new()
			buki_viewmodel.name = "BukiViewmodel"
			_cam.add_child(buki_viewmodel)
		buki_viewmodel.mostrar(slot)
	elif buki_viewmodel != null and is_instance_valid(buki_viewmodel):
		buki_viewmodel.esconder()
	_apply_perspective()

func buki_luneta(sim: bool) -> void:
	if buki_viewmodel != null and is_instance_valid(buki_viewmodel):
		buki_viewmodel.luneta(sim)

# MIRA ASSISTIDA: puxa devagar (não trava) para um ponto. Quem escolhe o ALVO é
# quem tem a arma; quem é dono de `_yaw`/`_pitch` é o Player — decisão da Fase 2,
# porque quem os escreve é o input.
func mirar_suave_para(ponto: Vector3, delta: float, forca: float) -> void:
	var para: Vector3 = ponto - _cam.global_position
	var h := Vector2(para.x, para.z).length()
	_yaw = lerp_angle(_yaw, atan2(-para.x, -para.z), forca * delta)
	_pitch = lerpf(_pitch, clampf(atan2(para.y, h), -1.2, 1.25), forca * delta)
	_update_pivot()
	if _char_model:
		# Na parede (wall run) o corpo é da parede: segue a tangente dela.
		if not _parkour.assumiu():
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw, 14.0 * delta)

# ⚠️ A BALA TEM QUE NASCER NO SERVIDOR, senão a `DamageZone` do cliente não fere
# ninguém e o sintoma vira "a arma não funciona" (docs/erros.md, 2026-08-10 —
# pistola da Yami). O canal é COMPARTILHADO com a rajada Z e a Yami: é por isso
# que a Fase 5 manteve os RPCs aqui em vez de levar o componente para nó filho.
func pedir_bala_da_buki(aim: Vector3, origem: Vector3, slot: String) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_bullet(aim, origem, slot)
	else:
		_net_bullet_req.rpc_id(1, aim, origem, slot)

# Encanamento de rede do saque/guardar. Fica no Player porque RPC se resolve por
# CAMINHO DE NÓ — mover o método mudaria o protocolo.
func avisar_servidor_do_saque(slot: String) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_buki_sacar(slot)
	else:
		_net_buki_sacar_req.rpc_id(1, slot)

func avisar_servidor_do_guardar() -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_buki_guardar()
	else:
		_net_buki_guardar_req.rpc_id(1)

# Pede a janela de ROLAMENTO. O maior pedido vence — dois gatilhos no mesmo
# quadro (pousar em cima de um dash) não devem encurtar a animação.
## O Q segue a esquiva do Epic Fight quando há uma arma do mod na mão (ver `DashController`).
func _esquiva_do_epic_fight() -> bool:
	var e := get_node_or_null("EspadaDaHistoria")
	return e != null and e.get("ativa") == true and str(e.get("lamina_ef")) != ""


func pedir_rolamento(duracao: float) -> void:
	_roll_t = maxf(_roll_t, duracao)

func add_camera_shake(amount: float) -> void:
	if _is_authority and _camera:
		_camera.pedir_shake(amount)

## Modo História: I aproxima e O afasta a câmera (segurando), e a roda do mouse fica com a hotbar (`HistoriaHud`). Falso na arena.
var zoom_por_teclas := false
const VELOCIDADE_DO_ZOOM := 6.0        # m/s de distância da câmera


func _zoom_por_teclas(delta: float) -> void:
	if not zoom_por_teclas or not _is_authority or _camera == null or _camera.em_primeira_pessoa() or _menu_de_tela_aberto():
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not ToqueHud.ativo():
		return
	aplicar_zoom((1.0 if Input.is_physical_key_pressed(KEY_O) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_I) else 0.0), delta)


## `sentido` +1 afasta (O), −1 aproxima (I). Separado da leitura das teclas para o teste dirigir sem teclado.
func aplicar_zoom(sentido: float, delta: float) -> void:
	if sentido != 0.0 and _camera != null and not _camera.em_primeira_pessoa():
		_camera.ajustar_distancia(sentido * VELOCIDADE_DO_ZOOM * delta)


func _process(delta: float) -> void:
	_zoom_por_teclas(delta)
	if not _is_authority or _camera == null:
		return
	# O rig recebe o estado de que precisa em vez de ir buscá-lo no Player —
	# é o que mantém a fronteira honesta e permite testá-lo sozinho.
	_camera.atualizar(delta, velocity, SPEED, is_on_floor(), _is_sprinting(), _yaw, _buki_scope,
		_parando_por_vontade())
	_camera.atualizar_agachar(delta, _agachar.queda_da_camera())
	if _gear2:
		_gear2.atualizar(delta)

# (Antiga função _processar_estados_de_combate removida, lógica movida para os States)

func _physics_process(delta: float) -> void:
	if _is_authority and _agachar.ativo and (not corpo_livre_para_golpe() \
			or not modo_na_agua.is_empty() or _voo.ativo()):
		_agachar.atualizar(false, false)
		net_agachado = _agachar.ativo
	# O vendaval é dono do movimento; câmera continua no _process. Este portão
	# vem antes de Rocket/FSM/parkour para nenhum deles sobrescrever a órbita.
	if esta_capturado_pelo_vento():
		if _is_authority:
			_etapa_vida(delta)
			_etapa_publicar_rede()
		return
	if _rocket != null and _rocket.tick(delta):
		# Golpe da Rocket no meio do voo: a forma de foguete se desfaz AQUI também,
		# porque este caminho pula a locomoção inteira.
		_sincronizar_forma_de_foguete(delta)
		return
	_sincronizar_forma_de_foguete(delta)
	# HITSTOP LOCAL: Personagem congela e treme após um golpe, segurando o knockback
	if _hitstop_timer > 0.0:
		if _animator and _animator.animation_player:
			_animator.animation_player.speed_scale = 0.0
		_hitstop_timer -= delta
		if _char_model:
			_char_model.position.x = randf_range(-0.06, 0.06)
			_char_model.position.z = randf_range(-0.06, 0.06)
		if _hitstop_timer <= 0.0:
			if _char_model:
				_char_model.position.x = 0.0
				_char_model.position.z = 0.0
			if _animator and _animator.animation_player:
				_animator.animation_player.speed_scale = 1.0
		_etapa_publicar_rede()
		return # Ignora o movimento, mas agora a rede continua sendo enviada

	if _fsm:
		_fsm._physics_process(delta)

	# ETAPAS NOMEADAS (Fase 1 da arquitetura, 2026-08-11).
	#
	# Este método tinha 291 linhas e misturava movimento, parkour, dash,
	# habilidades, energia, animação, rede, Buki, câmera e melee. Era por causa
	# dele que a contagem por domínio dizia "MOVIMENTO: 45 linhas" — a
	# movimentação de verdade morava aqui dentro, sem nome.
	#
	# ⚠️ NADA saiu do arquivo nesta fase, de propósito. O objetivo é enxergar as
	# dependências e a ORDEM antes de mover código: cada etapa abaixo já é uma
	# fronteira candidata a virar componente (ver docs/ARQUITETURA_PLAYER.md).
	#
	# A ordem NÃO é arbitrária, e duas etapas cortam o quadro:
	#   • sem autoridade, o corpo só reproduz o estado replicado e nada mais roda;
	#   • travado (cast, rajada, congelado, vórtice, buraco negro) o personagem
	#     fica parado e o quadro termina ali;
	#   • morto no vazio, o respawn acontece e o resto do quadro é descartado.
	if not _is_authority:
		_remote_process(delta)   # player de outro cliente: só reproduz o estado replicado
		return
	# ELIMINADO PELA ENCHENTE: só a gravidade e a rede continuam. A rede continua
	# de propósito — sem publicar, o corpo congelaria na tela dos outros no lugar
	# onde estava quando afundou.
	if _eliminado:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= GRAVITY * delta
		move_and_slide()
		if _morte_corpo_baixado and _proc_anim != null:     # o clipe `dying` anda e segura a pose final
			_proc_anim.update(Vector3.ZERO, is_on_floor(), false, delta, 0.0)
			_pousar_corpo_morto(delta)
		_etapa_publicar_rede()
		return
	_etapa_estado_de_combate(delta)
	if is_instance_valid(navegacao) and navegacao.atualizar(delta):
		_etapa_publicar_rede()
		_etapa_vida(delta)
		return
	if is_instance_valid(montaria) and montaria.atualizar(delta):
		_etapa_publicar_rede()
		_etapa_vida(delta)
		return
	# ⚠️ ANTES DO PORTÃO DE TRAVAMENTO, e isto NÃO é detalhe de ordem.
	# O tranco de dano estava depois, e a paralisia (que ESTE contador desliga)
	# faz `_etapa_travamento` devolver true — ou seja, o mecanismo que congela
	# bloqueava o relógio que descongela. Medido: alvo seguia congelado em 1,5 s
	# de uma paralisia de 1,2 s, e a pose nunca saía.
	# Mesma classe do item 23 (morrer segurando a tecla travava o jogo para
	# sempre): estado que só se apaga por um caminho que ele próprio fecha.
	var _hitstun_ativo = RecepcaoDeDano.tick(self, delta)
	if not _hitstun_ativo and _fsm and _fsm.state and _fsm.state.name == "Stunned":
		_fsm.transition_to("Idle")
	# Arremessado (voo, chão, levantar): o corpo não obedece input nenhum.
	if _arremesso.ativo():
		_etapa_arremesso(delta)
		return
	if _etapa_travamento(delta):
		return
	_etapa_locomocao(delta)
	_etapa_ticks_de_combate(delta)
	_etapa_publicar_rede()
	if _etapa_vida(delta):
		return
	_etapa_mover(delta)

# Energia, recargas e o laço das armas na mão. Roda SEMPRE que há autoridade —
# inclusive travado, senão a recarga congelaria junto com o personagem.
func _etapa_estado_de_combate(delta: float) -> void:
	_corpo_de_ferro.atualizar(delta)
	for g in _pistols:
		if is_instance_valid(g):
			# A Mera Z usa as mesmas armas durante a carga: primeiro nos coldres,
			# depois nas mãos. O rig é dono desse estado para não apagar a arma no
			# quadro entre o fim da carga e o primeiro disparo.
			g.visible = _rapid_fire or _yami_pistol_active or _rig.pistolas_em_saque()
	_vida.regenerar(delta)     # regen contínua de energia
	if _invisivel:
		energy = maxf(energy - dreno_da_invisibilidade() * delta, 0.0)
		if energy <= 0.0:
			revelar_invisibilidade()
	# RECARGA CONGELA DURANTE UMA HABILIDADE (regra do dono do projeto).
	# Enquanto um golpe está em andamento, a recarga das OUTRAS técnicas para de
	# correr — só a do próprio golpe em uso continua. Sem isso dava para segurar
	# um golpe longo (Black Hole, 7 s de trava) e sair dele com a barra inteira
	# recarregada de graça: o tempo de um golpe pagava o tempo de todos.
	if _trava_pos_fruta > 0.0:
		_trava_pos_fruta = maxf(_trava_pos_fruta - delta, 0.0)
	if _intervalo_golpe > 0.0:
		_intervalo_golpe = maxf(_intervalo_golpe - delta, 0.0)

	var em_uso := _slot_em_uso()
	# ⚠️ AS RECARGAS DE FRUTA PARAM enquanto a trava corre — ver a nota dela.
	# O `style` continua andando: a trava é dos poderes de fruta.
	for slot_k in _fruit_cooldowns.keys():
		if _trava_pos_fruta > 0.0:
			break
		if _fruit_cooldowns[slot_k] <= 0.0:
			continue
		if em_uso != "" and slot_k != em_uso and combat_mode == "fruit":
			continue                       # congelado: outra habilidade está ativa
		_fruit_cooldowns[slot_k] = maxf(_fruit_cooldowns[slot_k] - delta, 0.0)
	
	for slot_k in _style_cooldowns.keys():
		if _style_cooldowns[slot_k] <= 0.0:
			continue
		if em_uso != "" and slot_k != em_uso and combat_mode == "style":
			continue                       # congelado: outra habilidade está ativa
		_style_cooldowns[slot_k] = maxf(_style_cooldowns[slot_k] - delta, 0.0)
	if _combo_breaker_cooldown > 0.0:
		_combo_breaker_cooldown = maxf(_combo_breaker_cooldown - delta, 0.0)
	if _mink_bite_cooldown > 0.0:
		_mink_bite_cooldown = maxf(_mink_bite_cooldown - delta, 0.0)
	if _air_slam_cooldown > 0.0:
		_air_slam_cooldown = maxf(_air_slam_cooldown - delta, 0.0)
	if _fruit_damage_lock_timer > 0.0:
		_fruit_damage_lock_timer = maxf(_fruit_damage_lock_timer - delta, 0.0)
	if _spin_kick_cooldown > 0.0:
		_spin_kick_cooldown = maxf(_spin_kick_cooldown - delta, 0.0)
	if _asas_recarga > 0.0:
		_asas_recarga = maxf(_asas_recarga - delta, 0.0)
	if _asas_ativas:
		_tick_asas_de_anjo(delta)
	if _yami_pistol_active:
		_disparo.atualizar_yami(delta, _yaw, _pitch)
	if _buki.empunhando():
		# O coice visual é COMPARTILHADO com a rajada Z e a pistola da Yami, então
		# quem decai é o Player. O componente só pede (`pedir_coice_de_arma`).
		if _gun_recoil > 0.0:
			_gun_recoil = maxf(_gun_recoil - delta * 7.0, 0.0)
		_buki.atualizar(delta, _pitch, _yaw, net_facing)   # mira, cadência e munição

# O personagem está preso a alguma coisa? Devolve `true` quando consumiu o
# quadro — quem chama tem que devolver na hora, sem seguir para a locomoção.
func _etapa_arremesso(delta: float) -> void:
	_parkour.cancelar()   # arremessado larga a parede
	_deslize.cancelar()   # e o deslize
	_encolher_colisor(false)
	_arremesso.tick_dono(self, delta)
	if _skel_anim:
		_skel_anim.update(velocity, is_on_floor(), false, delta, false)
	elif _proc_anim:
		_proc_anim.update(velocity, is_on_floor(), false, delta, _pitch, false,
			false, "", "", false, 0.0, 0.0, -1, 0.0, _arremesso.pose_de_membros())
	_arremesso.apresentar(_char_model, delta)
	_etapa_publicar_rede()

func _etapa_travamento(delta: float) -> bool:
	# MAGU X (14/10/2026): o jogador SURFA a onda de lava. A técnica grava em `magu_surf`
	# a velocidade horizontal da onda; aqui o corpo a acompanha, de lado (pés ao longo
	# da prancha), sem ler teclas. Termina quando a técnica remove o meta.
	if has_meta("magu_surf"):
		var surf: Dictionary = get_meta("magu_surf")
		var rumo_surf: Vector3 = surf["rumo"]
		var pes: Vector3 = surf["pes"]
		velocity = Vector3.ZERO
		# Horizontal preso à crista; vertical sobe suave até ela (subida na prancha).
		global_position.x = pes.x
		global_position.z = pes.z
		global_position.y = lerpf(global_position.y, pes.y + float(surf["base"]), 1.0 - exp(-10.0 * delta))
		if _char_model:
			# O corpo olha para a DIREITA do rumo da onda (pé esquerdo à frente).
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, atan2(-rumo_surf.x, -rumo_surf.z) - PI * 0.5, 12.0 * delta)
		if _proc_anim:
			_proc_anim.update(velocity, true, false, delta, _pitch, false,
				false, "", "", false, 0.0, 0.0, -1, 0.0, str(get_meta("custom_pose", "")))
		return true
	var ope_action = (get_meta("ope_action") if has_meta("ope_action") else null)
	if is_instance_valid(ope_action) and get_meta("is_casting", false):
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		if _char_model:
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw, 18.0 * delta)
		if _proc_anim:
			_proc_anim.update(velocity, is_on_floor(), false, delta, _pitch, false,
				false, "", "", false, 0.0, 0.0, -1, 0.0, str(get_meta("custom_pose", "")))
		move_and_slide()
		return true
	# HOLD-TO-CAST / RAJADA Z: enquanto a tecla está SEGURADA (ou a rajada Z ativa), o
	# personagem fica PARADO — inclusive NO AR, sem gravidade — até soltar a tecla ou
	# as balas acabarem. Só a câmera continua livre (mira). A rajada dispara aqui.
	if _charging or _rapid_fire or (has_meta("is_frozen") and get_meta("is_frozen")) or (has_meta("in_vortex") and get_meta("in_vortex")) or (has_meta("in_kurouzu") and get_meta("in_kurouzu")) or (has_meta("in_black_hole") and get_meta("in_black_hole")):
		if _charging and not (has_meta("is_casting") and get_meta("is_casting")):
			_cast.abortar()            # cast foi interrompido (ex.: dano) -> destrava
		else:
			velocity = Vector3.ZERO    # congela no lugar (sem gravidade)
			
			if _breath:
				_breath.set_running(false)
			# Rajada Z: vira o corpo p/ a direção da mira (pose de pistoleiro) + coice decai.
			if _rapid_fire and _char_model:
				if not _parkour.assumiu():
					_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw, 18.0 * delta)
			if _gun_recoil > 0.0:
				_gun_recoil = maxf(_gun_recoil - delta * 7.0, 0.0)
			if _proc_anim:
				# Na RAJADA Z não passa charge_slot: senão herda o active_skill ("C") e o
				# animator aplica o tremor de torso do Gatling, quebrando a pose das pistolas.
				var pose_custom := str(get_meta("custom_pose", ""))
				var slot_to_pass = "" if _pose_de_arma() or pose_custom == "mera_z_charge" or pose_custom == "mera_x_charge" else (_charge_slot if _charging else get_meta("active_skill", ""))
				var mera_z_progress := _cast.progresso_mera_z() if _cast else 0.0
				var mera_x_progress := _cast.progresso_mera_x() if _cast else 0.0
				# Esta publicação fica no caminho travado porque o `return` abaixo não
				# deixa `_etapa_publicar_rede` rodar enquanto a tecla está pressionada.
				net_charge_pose = pose_custom if pose_custom in ["mera_z_charge", "mera_x_charge"] else ""
				net_charge_progress = mera_x_progress if pose_custom == "mera_x_charge" else mera_z_progress if pose_custom == "mera_z_charge" else 0.0
				_proc_anim.update(velocity, is_on_floor(), false, delta, _pitch, false, _charging, slot_to_pass, "", _pose_de_arma(), _gun_recoil, mera_z_progress, _disparo.lado_do_ultimo_tiro(), mera_x_progress, pose_custom)
			move_and_slide()
			_disparo.tick_rajada(delta, energia_do_modo(ENERGY_BULLET))    # dispara as balas de fogo/gelo enquanto a rajada dura
			
			# ⚠️ Quem chegou aqui está travado por definição. O quadro
			# acaba aqui para TODOS os motivos de trava.
			return true
	return false

# O CICLO FÍSICO — quem manda na velocidade deste quadro.
#
# Era um bloco de 206 linhas com entrada, parkour, dash, locomoção, facing e
# animação misturados, disputando 16 locais de quadro. A Fase 4 separou por
# RESPONSABILIDADE, não por verbo:
#
#   src/player/move_frame.gd         o que o jogador PEDIU (teclas + câmera)
#   src/player/parkour_controller.gd os 8 movimentos de cenário + as sondas
#   src/player/dash_controller.gd    a esquiva do Q
#
# A ordem abaixo é a regra do jogo, e é por isso que ela mora AQUI e não nos
# componentes: nenhum deles escreve `velocity`. Eles recebem e devolvem; quem
# atribui é esta etapa. Escalada e wall run são exclusivos — enquanto valem, o
# parkour manda sozinho e nem a gravidade roda.
#
# Sobraram 7 locais de quadro (eram 16). Continuam aqui de propósito: são o
# RESULTADO das decisões, e é justamente combiná-los que esta etapa faz.
## Em combate: atacando, carregando/usando skill, mirando arma, voando pilotado
## ou com golpe contextual — e por COMBATE_SEGURA s depois disso. O roll (Q) NÃO
## conta: ele tem frente própria — o corpo vira para onde rola.
func _em_combate() -> bool:
	return _combate_t > 0.0


## DESLIZE: colisão (e hurtbox) pela METADE, com os pés no mesmo lugar — o centro
## desce um quarto da altura. Guarda o tamanho inteiro (pode ter escala de raça) e o
## devolve EXATO. Chamado todo quadro; só age quando o estado muda.
func _encolher_colisor(sim: bool) -> void:
	if sim == _encolhido or not is_instance_valid(_colisor):
		return
	_encolhido = sim
	var caixa := _colisor.shape as BoxShape3D
	var capsula := _colisor.shape as CapsuleShape3D
	if sim:
		var alt: float = caixa.size.y if caixa else (capsula.height if capsula else COLISOR_BASE.y)
		_colisor_inteiro = {"pos": _colisor.position, "alt": alt, "raio": capsula.radius if capsula else 0.0}
		if caixa:
			caixa.size.y = alt * 0.5
		elif capsula:
			# Cápsula não fica mais baixa que o próprio diâmetro: o raio encolhe junto
			# (com raio 0,5 m ela parava em 1,01 m, a base afundava no chão e a
			# física a empurrava para cima — a barra baixa bloqueava; medido 03/10).
			capsula.radius = minf(capsula.radius, alt * 0.25)
			capsula.height = alt * 0.5
		_colisor.position.y = float((_colisor_inteiro["pos"] as Vector3).y) - alt * 0.25
		if colisor_capsula:
			var e := escala_do_corpo()
			HurtboxDeCombate.redimensionar(self, Vector3(COLISOR_BASE.x * e, alt * 0.5, COLISOR_BASE.z * e), _colisor.position.y)
	else:
		var alt: float = _colisor_inteiro.get("alt", COLISOR_BASE.y)
		if caixa:
			caixa.size.y = alt
		elif capsula:
			capsula.radius = float(_colisor_inteiro.get("raio", capsula.radius))
			capsula.height = alt
		_colisor.position = _colisor_inteiro.get("pos", Vector3.ZERO)
		if colisor_capsula:
			var e := escala_do_corpo()
			HurtboxDeCombate.redimensionar(self, COLISOR_BASE * e, _colisor.position.y)


## Cabe de pé aqui? Raios do centro do corpo até o topo da colisão INTEIRA (no
## centro e a 0,25 m para os quatro lados). Fora do deslize, sempre cabe.
func _teto_livre() -> bool:
	if not _encolhido:
		return true
	var alt: float = _colisor_inteiro.get("alt", COLISOR_BASE.y)
	var centro := global_position + Vector3.UP * float((_colisor_inteiro.get("pos", Vector3.ZERO) as Vector3).y)
	var espaco := get_world_3d().direct_space_state
	for desvio in [Vector3.ZERO, Vector3(0.25, 0, 0), Vector3(-0.25, 0, 0), Vector3(0, 0, 0.25), Vector3(0, 0, -0.25)]:
		var de: Vector3 = centro + desvio
		var par := PhysicsRayQueryParameters3D.create(de, de + Vector3.UP * (alt * 0.5 + 0.02))
		par.exclude = [get_rid()]
		# Sem a camada da HURTBOX: ela é filha do jogador e, encolhida, tem o topo
		# exatamente na origem do raio — acusava teto em campo aberto (medido 03/10).
		par.collision_mask = ~HurtboxDeCombate.CAMADA & 0xFFFFFFFF
		if not espaco.intersect_ray(par).is_empty():
			return false
	return true


## Soltou as teclas no chão e o corpo está freando: para a câmera isso já é parar
## (ela obedece à decisão do jogador, não ao fim da frenagem).
func _parando_por_vontade() -> bool:
	return is_on_floor() and _quadro.dir == Vector3.ZERO \
		and _loco_chao.estado in ["freando", "derrapando", "parado"]


func _atualizar_combate(delta: float) -> void:
	var agora: bool = (_fsm != null and _fsm.state != null and _fsm.state.name != "Idle") \
		or (combate_direcional != null and combate_direcional.ocupado()) \
		or _charging or _rapid_fire or _yami_pistol_active or _buki_scope or _pose_de_arma() \
		or not _contextual_attack_id.is_empty() or _voo.ativo() \
		or (_yoru_combat != null and not String(_yoru_combat.action_id).is_empty()) \
		or (has_meta("custom_pose") and not str(get_meta("custom_pose")).is_empty())
	_combate_t = COMBATE_SEGURA if agora else maxf(_combate_t - delta, 0.0)


func _etapa_locomocao(delta: float) -> void:
	# LEITURA do quadro: teclas + base da câmera -> src/player/move_frame.gd.
	# A etapa passou a DECIDIR sobre um pedido já lido, em vez de ler e decidir
	# ao mesmo tempo. Ler aqui dentro (e não antes) é de propósito: quando o
	# `_etapa_travamento` corta o quadro, a borda do Espaço NÃO avança — mesmo
	# comportamento de quando `_space_was` era campo do Player.
	var q := _quadro
	var menu_aberto := false
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("is_menu_open"):
		menu_aberto = hud.is_menu_open()
		
	q.ler(_yaw, not menu_aberto)
	var pode_agachar: bool = modo_na_agua.is_empty() and not _parkour.assumiu() \
		and not esquivando() and not _voo.ativo() and not _movimento_de_skill_ativo() \
		and not _flutuar_por_skill and corpo_livre_para_golpe()
	_agachar.atualizar(q.agachar_segurado, pode_agachar)
	if _agachar.ativo:
		q.sprint = false
	_atualizar_combate(delta)
	# Modo História (03/10/2026): arma de fruta sacada (Yami, Buki) fica com os botões
	# do mouse, como na arena — o combate direcional não soca nem ergue guarda.
	if entrada_combate_direcional != null:
		entrada_combate_direcional.suspensa = _yami_pistol_active or _buki_weapon != ""
	# Rajada (Mera/Hie Z): fica PARADO enquanto atira; só a câmera gira. Volta a
	# andar ao soltar o botão ou acabar as balas (release_charge zera _rapid_fire).
	if _rapid_fire or (has_meta("custom_pose") and get_meta("custom_pose") == "knockdown"):
		q.congelar()
	elif _cast.kit_prende_o_andar() or habilidade_segurada_prende():
		q.travar_por_skill()           # segurando skill do Builder: não anda, não pula, não esquiva

	# PARKOUR -> src/player/parkour_controller.gd. Uma chamada resolve pouso de
	# precisão, sondagem de parede, decisão de escalar/correr na parede e recarga
	# do geppo. Antes isso estava espalhado em quatro pedaços da etapa.
	var on_floor_now := is_on_floor()
	_parkour.avaliar(delta, q, on_floor_now)

	if _roll_t > 0.0:
		_roll_t -= delta

	# ESQUIVA (Q) -> src/player/dash_controller.gd. Ele cuida de mira, recarga,
	# direção travada e tempo restante; aqui só se pergunta o que ele quer.
	# DASH-CANCEL — agora só na RECUPERAÇÃO, e só se o golpe conectou.
	#
	# Antes valia em "Attacking" inteiro, o que incluía o startup: dava para
	# apertar, ver que ia acertar e sumir antes mesmo de a hitbox nascer. Com
	# as três fases a regra fica onde o §4.1 a colocou — startup e ativo são
	# compromisso, recuperação é onde há escolha.
	#
	# Quem responde é o próprio estado (`pode_cancelar_para_dash`), não um `if`
	# aqui: a regra do cancelamento é do estado que a sofre.
	var dash_bloqueado := _charging or _rapid_fire or _yami_pistol_active or (_yoru_combat != null and not String(_yoru_combat.action_id).is_empty())
	# Combate direcional: mesmo molde da Yoru — golpe em curso é do executor, e a
	# esquiva não o corta (o Roll em si não muda).
	if combate_direcional != null and combate_direcional.ocupado():
		dash_bloqueado = true
	if _fsm and _fsm.state and _fsm.state.name != "Idle":
		dash_bloqueado = true
		if _fsm.state.name == "AttackRecovery" and _fsm.state.pode_cancelar_para_dash():
			dash_bloqueado = false # Dash cancel liberado!
	# O roll (Q) NÃO depende mais da capacidade `can_dash` — decisão do dono
	# (03/10/2026): "liberar o uso do Q", roll sempre liberado. O desbloqueio
	# "dash" da progressão continua existindo no save, só não trava o Q.

	dash_bloqueado = dash_bloqueado or (_agachar.ativo and not _agachar.pode_levantar())
	_dash.modo_ef = _esquiva_do_epic_fight()
	_dash.atualizar(delta, q, dash_bloqueado)
	_dash_ar.atualizar(delta, q, dash_bloqueado, _mira_do_dash())
	if esquivando() and _agachar.ativo:
		_agachar.cancelar()
	if esquivando():
		_cancel_yoru_action("dash")

	if esquivando() and _fsm and _fsm.state and _fsm.state.name != "Idle":
		# O golpe em voo morre junto com o estado. Sem isso o `MeleeController`
		# seguiria contando as fases de um golpe que a esquiva já cancelou, e a
		# `fase()` mentiria para a FSM no quadro seguinte.
		if _melee and _fsm.state.name in ESTADOS_DE_ATAQUE:
			_melee.cancelar_golpe()
		_fsm.transition_to("Idle") # Quebra o estado de combate se o dash conseguiu disparar

	# M1 normal não prende mais o deslocamento: o jogador pode andar enquanto
	# soca/chuta. As exceções são estilos especiais que controlam a própria
	# velocidade (hoje, a mordida Mink ao segurar alguém).
	var golpe_prende := _mink_hold_timer > 0.0 or (_yoru_combat != null and not String(_yoru_combat.action_id).is_empty())
	if golpe_prende:
		q.travar_golpe()

	# `bonus_velocidade` é o impulso horizontal do salto longo / vault: o parkour
	# devolve o FATOR e quem multiplica é a etapa. Componente não escreve na
	# velocidade dos outros.
	# A corrida começa em 1,5× a caminhada e, mantida no chão por 3 segundos,
	# chega ao dobro dela (3× a caminhada). Qualquer interrupção zera o embalo.
	# CORRER = 1,5× ANDAR, e só (decisão do dono, 03/10/2026: "retirar o ganho de
	# velocidade ao correr"). Até então a corrida crescia até 2× em 3 s no chão.
	# O buff de aceleração da Rocket (V) passou para a arrancada da locomoção.
	var fator_nado: float = controle_da_agua.fator_de_movimento(self, q, delta) if is_instance_valid(controle_da_agua) else (1.5 if q.sprint else 1.0) * fator_da_agua
	var effective_speed := SPEED * speed_multiplier * velocidade_mod * (float(_rocket.fator_velocidade()) if _rocket != null else 1.0) * fator_nado * _parkour.bonus_velocidade() \
		* ExecutorDeSkill.fator_de_lentidao(self) \
		* float(get_meta("arco_fator_velocidade", 1.0)) * float(get_meta("ef_fator_velocidade", 1.0))      # lentidão das skills do Builder; e puxando a pokébola (×0,2, como o arco)
	if _agachar.ativo:
		effective_speed *= _agachar.FATOR_VELOCIDADE
	# Combate direcional: o golpe TIRA mobilidade sem congelar — o fator por fase
	# vem da ficha do golpe (1,0 fora de ação).
	if combate_direcional != null:
		effective_speed *= combate_direcional.fator_de_movimento()
	if get_meta("magu_cao_ativo", false):
		# C: exatamente duas vezes a corrida, com ou sem Shift. Desde a locomoção do Minecraft (31/10/2026) a corrida é ×1,3 sobre andar, aplicada pelo `McMovimento`
		# (o `mult_mc` abaixo desconta o `fator_nado` 1,5 do Shift): com Shift a conta é 3,0/1,5 × 1,3 = 2,6; sem Shift não há ×1,3 e o fator é 2,6 direto.
		# Com o 1,5 antigo o cão saía 2,3× a corrida (medido em 15/11/2026: 11,40 contra 4,94 m/s).
		effective_speed = SPEED * speed_multiplier * (3.0 if q.sprint else 2.6)
	if _dash_ar.acabou():
		# Fim do dash do ar (pedido do dono, 08/10/2026): o impulso não continua — a
		# velocidade horizontal volta à de andar, senão o corpo seguia a 18 m/s no ar.
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		if horizontal.length() > effective_speed:
			horizontal = horizontal.normalized() * effective_speed
			velocity.x = horizontal.x
			velocity.z = horizontal.z
		if absf(_dash_ar.direcao().y) > 0.001:
			velocity.y = 0.0

	# QUEM MANDA NA VELOCIDADE DESTE QUADRO.
	var mc_usado := false
	# Escalada e wall run são exclusivos: enquanto valem, o parkour manda sozinho.
	if _parkour.assumiu():
		velocity = _parkour.velocidade(delta, q, velocity, effective_speed)
	else:
		# Gravidade — na água funda, flutuação (ou o afundar do usuário de fruta).
		if modo_na_agua == "nadando" and is_instance_valid(controle_da_agua):
			pass   # nado livre: o vertical sai da mira e do teclado, mais abaixo
		elif not modo_na_agua.is_empty():
			velocity.y = lerpf(velocity.y, agua_vertical, 1.0 - exp(-6.0 * delta))
		elif not is_on_floor():
			velocity.y -= GRAVITY * delta
			# A queda esmagadora usa exatamente 3× a aceleração da gravidade. A
			# velocidade do clique já foi triplicada na ativação; esta linha mantém
			# a mesma proporção até o pouso, sem impor uma velocidade artificial.
			if _air_slam_active:
				velocity.y -= GRAVITY * delta * 2.0

		# Vault, salto longo, pulo normal e geppo: o parkour recebe a velocidade
		# e devolve a velocidade — não escreve nela.
		if modo_na_agua.is_empty():
			velocity = _parkour.aplicar_pulos(q, velocity, effective_speed, is_on_floor(), jump_multiplier * pulo_mod)

		var goro_mp := GoroGoroMinePiece.de(self)
		var fruta_mp := ControladorFrutaMinePiece.de(self)
		if _phoenix != null and _phoenix.controla_movimento():
			velocity = _phoenix.velocidade(delta, velocity, q, _mira_do_voo())
		elif goro_mp != null and goro_mp.controla_movimento():
			# Goro Goro (Mine Piece): técnica em curso prende o corpo; transformado, voa.
			velocity = goro_mp.velocidade(delta, velocity, q)
		elif fruta_mp != null and fruta_mp.controla_movimento():
			# Demais frutas Mine Piece: Lentidão X da técnica prende; logia transformada voa.
			velocity = fruta_mp.velocidade(delta, velocity, q)
		elif _voo.ativo():
			# Voo da fruta (Blast Off). Dano, morte ou perder a fruta encerram PELO
			# POUSO: acabar o voo não pode matar de queda.
			if not corpo_livre_para_golpe() or not capacidades.can_fly:
				_voo.desfazer_forma()
			velocity = _voo.velocidade(delta, _mira_do_voo(), is_on_floor())
			set_meta("custom_pose", "rocket_voo" if _voo.no_ar() else "")
		elif _dash.passo() > 0.0:
			velocity = _dash.velocidade(delta)
		elif _dash_ar.passo() > 0.0:
			velocity = _dash_ar.velocidade(delta)
		elif _deslize.ativo():
			var livre := _teto_livre()
			var hv: Vector3 = _deslize.atualizar(delta, is_on_floor(), livre, q.espaco_agora)
			velocity.x = hv.x
			velocity.z = hv.z
			if not livre:
				velocity.y = minf(velocity.y, 0.0)    # sob teto baixo não há pulo

		elif _movimento_de_skill_ativo():
			# Skill do Builder com bloco de Movimento: quem escreve é o executor, a
			# colisão é a do próprio corpo (`move_and_slide`). Andando no chão, a
			# gravidade continua; "Acima" manda também no vertical.
			velocity.x = _mov_skill_vel.x
			velocity.z = _mov_skill_vel.z
			if _mov_skill_vertical:
				velocity.y = _mov_skill_vel.y
			elif _flutuar_por_skill:
				velocity.y = 0.0
		elif _flutuar_por_skill:
			# Skill que flutua, entre um movimento e outro: parado no ar.
			velocity = Vector3.ZERO
		elif (_cast.kit_paralisa() or habilidade_segurada_paralisa()) and corpo_livre_para_golpe():
			# Segurando o Z da Pika no Modo História (10/10/2026): parado onde está, até no
			# ar. Golpe, captura ou congelamento (corpo não livre) continuam mandando.
			velocity = Vector3.ZERO
		elif _bomu_rush_active:
			velocity.x = _bomu_rush_dir.x * effective_speed * 4.6
			velocity.z = _bomu_rush_dir.z * effective_speed * 4.6
			_process_bomu_rush(delta)
		elif _gura_rush_active:
			velocity.x = _gura_rush_dir.x * effective_speed * 4.0
			velocity.z = _gura_rush_dir.z * effective_speed * 4.0
			_process_gura_rush(delta) # HITBOX e Timer da Investida!
		elif _mink_bite_dash:
			velocity.x = _mink_bite_dir.x * effective_speed * 3.8
			velocity.z = _mink_bite_dir.z * effective_speed * 3.8
			_process_mink_bite(delta)
		elif _mink_hold_timer > 0.0:
			velocity.x = 0.0
			velocity.z = 0.0
			_process_mink_hold(delta)
		elif _melee and _melee.contextual_ativo():
			_processar_movimento_contextual()
		elif _spin_kick_active:
			var giro_frente := RosaDosVentos.frente(_spin_kick_yaw)
			velocity.x = giro_frente.x * 8.0
			velocity.z = giro_frente.z * 8.0
		elif modo_na_agua == "nadando" and is_instance_valid(controle_da_agua):
			# Nado livre (14/10/2026): mouse + W/A/S/D dão a direção em 3D, sem boiar sozinho.
			var nado: Vector3 = controle_da_agua.velocidade_de_nado(global_position, q, _mira_do_voo(), effective_speed)
			velocity.x = nado.x
			velocity.z = nado.z
			velocity.y = lerpf(velocity.y, nado.y, 1.0 - exp(-6.0 * delta))
			_loco_chao.acompanhar(delta, velocity, q.dir)
		elif not modo_na_agua.is_empty():
			# Na água o nado tem controle próprio (jogador_na_agua.gd); sem
			# arrancada/frenagem de corrida.
			velocity.x = q.dir.x * effective_speed
			velocity.z = q.dir.z * effective_speed
			_loco_chao.acompanhar(delta, velocity, q.dir)
		else:
			# ARRANCADA, FRENAGEM, GIRO E CURVA -> src/player/locomocao_chao.gd.
			# No impulso do salto longo/vault o controle no ar fica firme (como
			# combate), senão o bônus de velocidade não chegaria a valer.
			# MOVIMENTAÇÃO DO MINECRAFT (31/10/2026) -> src/player/movimento_minecraft.gd. É a ÚNICA
			# locomoção de chão/ar. O que sobra do multiplicador depois de tirar a corrida e o
			# agachar (que o Minecraft faz sozinho: ×1,3 e ×0,3) vira o atributo de velocidade.
			var mult_mc := effective_speed / (SPEED * maxf(fator_nado, 0.001))
			if _agachar.ativo:
				mult_mc /= _agachar.FATOR_VELOCIDADE
			mc_usado = true
			velocity = _mc_mov.velocidade(delta, self, q, velocity, mult_mc, _agachar.ativo, GRAVITY,
				jump_multiplier * pulo_mod)
			_loco_chao.observar(delta, velocity, q.dir, is_on_floor(), _agachar.ativo or _em_combate())

	if not mc_usado:
		_mc_mov.soltar()       # outro ramo mandou neste quadro: o Minecraft reentra do que o corpo fez

	# Deslize: colisão pela metade enquanto o corpo está baixo (só age na troca).
	_encolher_colisor(_deslize.encolhido())

	# ============================================================ A FRENTE
	# ⚠️ LIVRE o corpo olha para onde ANDA; EM COMBATE, para a MIRA. Decisão do
	# dono (2026-10-02, docs/PARKOUR_MIRRORS_EDGE_PLANO.md), que substitui a de
	# 2026-08-27 ("olha para a mira, sempre") fora do combate.
	#
	# A regra de 27/08 continua valendo onde nasceu: o golpe sai para onde a MIRA
	# aponta (`melee_controller` e as skills usam `_yaw`, não `q.dir`), e um corpo
	# de costas para quem ele vai acertar lê errado. Por isso atacar, usar skill,
	# mirar ou dar dash vira o corpo para a mira e o mantém lá por COMBATE_SEGURA s
	# (`_em_combate`). Correndo livre, a frente é a do movimento — é ela que faz a
	# arrancada, o giro e a inclinação de curva lerem (`src/player/locomocao_chao.gd`).
	#
	# ⚠️ DUAS EXCEÇÕES, e elas não são negociáveis: NA PAREDE. Escalando, a frente
	# vira para DENTRO da parede porque é isso que faz a escalada ler — um
	# personagem grudado numa parede de costas para ela seria pior que o problema
	# original. No wall run, a frente segue a TANGENTE da parede (para onde ele
	# corre). Aqui a mira não manda porque o corpo está preso à geometria.
	if _char_model:
		if _parkour.correndo_na_parede():
			var rumo_parede := LocomocaoChao.yaw_de(_parkour.parede.tangente)
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, rumo_parede,
				VELOCIDADE_FACING_GIRO * delta)
			_loco_chao.rumo = _char_model.rotation.y   # sai da parede de onde está
		elif esquivando() or _deslize.ativo():
			# Roll e deslize seguem o rumo; o dash aéreo mantém a frente da câmera.
			var rumo_esquiva := _dash.rumo_do_corpo() if _dash.ativo() else (_dash_ar.frente_do_corpo() if _dash_ar.ativo() else _deslize.direcao())
			var rumo_roll := LocomocaoChao.yaw_de(rumo_esquiva)
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, rumo_roll,
				clampf(VELOCIDADE_FACING_GIRO * 2.0 * delta, 0.0, 1.0))
			_loco_chao.rumo = _char_model.rotation.y
		elif _parkour.escalando():
			# Convenção do projeto: FRENTE = −Z. Escalando, a frente aponta PARA
			# DENTRO da parede (−normal; a normal aponta da parede para o jogador).
			var rumo_escalada := LocomocaoChao.yaw_de(-_parkour.escalada.normal)
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, rumo_escalada,
				VELOCIDADE_FACING_GIRO * delta)
			_loco_chao.rumo = _char_model.rotation.y
		elif not _contextual_attack_id.is_empty():
			# W/A/S/D fixa a direção no clique. A câmera ainda gira para mirar o
			# próximo golpe, mas não altera a silhueta do corpo comprometido.
			_char_model.rotation.y = _contextual_attack_yaw
		elif combate_direcional != null and combate_direcional.ocupado():
			# Combate direcional: o corpo continua seguindo a mira, mas com TETO de
			# giro por fase (ficha do golpe). Sem ele, girar a câmera no ativo
			# arrastaria o golpe em volta do corpo inteiro.
			var atual := _char_model.rotation.y
			var passo := wrapf(lerp_angle(atual, _yaw, VELOCIDADE_FACING * delta) - atual, -PI, PI)
			var teto := combate_direcional.giro_maximo() * delta
			_char_model.rotation.y = atual + clampf(passo, -teto, teto)
		elif has_meta("frente_forcada"):
			# Quem segura o corpo virado para um ponto (a PESCA, para a boia — 03/10/2026)
			# grava o yaw nesta meta e a apaga ao soltar.
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, float(get_meta("frente_forcada")),
				VELOCIDADE_FACING * delta)
			_loco_chao.rumo = _char_model.rotation.y
		elif _em_combate() or _agachar.ativo:
			# EM COMBATE o corpo olha para a MIRA (o golpe sai por `_yaw`).
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw,
				VELOCIDADE_FACING * delta)
			_loco_chao.rumo = _char_model.rotation.y   # sai do combate de onde está
		else:
			# LIVRE o corpo segue o MOVIMENTO; no giro, o pivô é rápido.
			var taxa := VELOCIDADE_FACING_GIRO if _loco_chao.estado in ["girando", "freando_giro"] else VELOCIDADE_FACING_LIVRE
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _loco_chao.rumo, taxa * delta)

	# A mira normalmente reescreve a orientação do modelo a cada quadro. Na aú,
	# isso mudaria o eixo da rotação no meio do movimento: captura-se o yaw no
	# clique e a estrelinha inteira segue a visão daquele instante.
	if _char_model and _spin_kick_active:
		_spin_kick_angle = fmod(_spin_kick_angle + TAU * delta / 0.42, TAU)
		var angulo_au := -_spin_kick_angle
		# A aú começa DE LADO para a câmera. Com o corpo 90° à direita, o eixo
		# lateral local (X) aponta para a frente da visão capturada, e a roda
		# atravessa o rumo do jogador em vez de fazê-lo cambalhotar para o lado.
		_char_model.rotation.y = _spin_kick_yaw + PI * 0.5
		_char_model.rotation.z = angulo_au
		_char_model.position.x = _spin_kick_rest_position.x + ALTURA_DO_ROLAMENTO * sin(angulo_au)
		_char_model.position.y = _spin_kick_rest_position.y + ALTURA_DO_ROLAMENTO * (1.0 - cos(angulo_au))

	_inclinar_no_wall_run(delta, _parkour.parede.lado if _parkour.correndo_na_parede() else 0)

	# Fim do arremesso: o corpo termina de voltar de pé suavemente.
	_arremesso.apresentar(_char_model, delta)

	# Animação: rig procedural (por-nós) OU esqueletal (skinnado).
	if _skel_anim:
		_skel_anim.update(velocity, is_on_floor(), _parkour.escalando(), delta, q.sprint)
	elif _proc_anim:
		var parkour := ""
		var estado_escalada: String = _parkour.escalada.estado
		if estado_escalada == "borda":
			parkour = "borda"
		elif estado_escalada == "subindo":
			parkour = "subindo_borda"
		elif _parkour.correndo_na_parede():
			parkour = "wall_run"
		elif _roll_t > 0.0:
			# Roll do Q e rolamento de pouso. O do Q toca o clipe do Mixamo (ver
			# `acao_clipe` logo abaixo); o de pouso fica na pose procedural.
			parkour = "roll"
		elif _parkour.janela_impulso() > 0.0 and not on_floor_now:
			parkour = "long_jump"
		if _agachar.ativo:
			parkour = "agachar"
		# No wall run o animador recebe a corrida AO LONGO da parede (sem a pressão
		# de contato contra ela) e o lado da parede, para a mão de apoio.
		var vel_anim: Vector3 = velocity
		if _parkour.correndo_na_parede():
			vel_anim = _parkour.parede.tangente * _parkour.parede.velocidade_ao_longo() + Vector3.UP * velocity.y
		elif _parkour.escalando():
			# Sem a pressão contra a parede: é contato, não deslocamento.
			var n_esc: Vector3 = _parkour.escalada.normal
			vel_anim = velocity - n_esc * velocity.dot(n_esc)
		_proc_anim.parede_lado = _parkour.parede.lado if _parkour.correndo_na_parede() else 0
		_proc_anim.subida_borda = _parkour.escalada.progresso_subida
		_proc_anim.loco_inclinacao = _loco_chao.inclinacao
		_proc_anim.loco_inclinacao_frente = _loco_chao.inclinacao_frente
		_proc_anim.loco_estado = _loco_chao.estado
		_parkour_anim = parkour
		# CLIPE DE AÇÃO (03/10/2026): o roll do Q toca o "Sprinting Forward Roll" no
		# tempo que a física do roll manda — o corpo inteiro segue o clipe.
		if _dash.rolando():
			_proc_anim.acao_clipe = _dash.clipe()
			_proc_anim.acao_tempo = _dash.tempo_do_clipe()
			_parkour_anim = "roll_q"
		elif _dash_ar.ativo():
			# Dash no ar: impulso com o pé, diferente para cada direção.
			_proc_anim.acao_clipe = _dash_ar.clipe()
			_proc_anim.acao_tempo = _dash_ar.tempo_do_clipe()
			_parkour_anim = "roll_q"
		elif _deslize.ativo():
			_proc_anim.acao_clipe = Deslize.CLIPE
			_proc_anim.acao_tempo = _deslize.tempo_do_clipe()
			_parkour_anim = "deslize"
		elif _clipe_de_skill != "":
			# Bloco Animação do Skills Builder (07/10/2026): o clipe no tempo do bloco.
			_proc_anim.acao_clipe = _clipe_de_skill
			_proc_anim.acao_tempo = _tempo_clipe_de_skill
		else:
			_proc_anim.acao_clipe = ""
		var do_builder := _proc_anim.acao_clipe == _clipe_de_skill and _clipe_de_skill != ""
		_proc_anim.acao_peso = _peso_clipe_de_skill if do_builder else 1.0
		# Só o "escalando" (escada) usa a pose de escalada; borda e subida têm as suas.
		_proc_anim.update(vel_anim, is_on_floor(), estado_escalada == "escalando", delta, _pitch, q.sprint, false, "", parkour, _pose_de_arma(), _gun_recoil)

# Fôlego, rajada Z e a janela do combo de corpo a corpo.
func _etapa_ticks_de_combate(delta: float) -> void:
	_update_breath()
	_disparo.tick_rajada(delta, energia_do_modo(ENERGY_BULLET))   # Mera Z: dispara as balas de fogo enquanto a rajada está ativa
	_melee.tick(delta, _yaw)  # corpo a corpo: janela do combo + recuperação

# A autoridade publica seu estado para os outros clientes replicarem.
func _etapa_publicar_rede() -> void:

	# Rede (Fase 4): a autoridade publica seu estado p/ os outros clientes replicarem.
	net_velocity = velocity
	net_on_floor = is_on_floor()
	net_parkour = "agachar" if _agachar.ativo else ("" if _parkour_anim == "agachar" else _parkour_anim)
	net_agachado = _agachar.ativo
	net_escalando = _parkour.escalada.estado == "escalando"
	net_parede_lado = _parkour.parede.lado if _parkour.correndo_na_parede() else 0
	net_acao_clipe = _proc_anim.acao_clipe if _proc_anim else ""
	net_acao_tempo = _proc_anim.acao_tempo if _proc_anim else 0.0
	net_subida = _parkour.escalada.progresso_subida
	net_inclinacao = Vector2(_loco_chao.inclinacao, _loco_chao.inclinacao_frente)
	# A cópia local acabou a carga; limpa o estado visual que foi replicado no
	# caminho de trava. O golpe final continua viajando pelo RPC de cast normal.
	net_charge_pose = ""
	net_charge_progress = 0.0
	if _char_model:
		net_facing = _char_model.rotation.y

# Supressão de poderes e morte por queda. Devolve `true` se o quadro acabou aqui.
func _etapa_vida(delta: float) -> bool:
	if knockback_minecraft != null:
		knockback_minecraft.passar_tempo(delta)

	# Processamento de Supressão da Passiva Yami Yami
	_cast.tick_silencio(delta)

	# Verificação de Void (Morte ao cair no Void)
	if SkillSystem.process_void_check(self):
		return true
	return false

# Aplica o empurrão externo e move de fato. É o ÚLTIMO passo do quadro: o
# knockback tem que entrar DEPOIS de a locomoção escrever `velocity`, senão ela
# o sobrescreve (foi exatamente esse o bug do empurrão que não funcionava).
func _etapa_mover(delta: float) -> void:
	velocity = _agachar.limitar_borda(velocity, delta)

	# Empurrão externo: somado DEPOIS da locomoção ter escrito velocity, e antes
	# de mover. Decai sozinho, então o controle volta ao jogador em ~1 s.
	# É AQUI que o diagrama da arquitetura acontece: a locomoção já escreveu
	# `velocity`, e agora o empurrão — que é de OUTRO dono — é somado por cima.
	#
	# O `if` não é otimização: somar `Vector3.ZERO` normaliza −0,0 para +0,0, e o
	# traço de 492 quadros acusou exatamente isso (posições idênticas, sinal do
	# zero diferente). Sem empurrão, não se toca na velocidade — como antes.
	var empurrao := _vida.impulso_do_quadro(delta)
	if empurrao != Vector3.ZERO:
		velocity += empurrao
	# Knockback Minecraft (Modo História): o mesmo molde, com o atrito do Minecraft.
	if knockback_minecraft != null:
		var empurrao_mc := knockback_minecraft.impulso_do_quadro(delta, is_on_floor())
		if empurrao_mc != Vector3.ZERO:
			velocity += empurrao_mc
	# Combate direcional: o avanço do golpe é outro dono somando por cima, no mesmo
	# molde (e com o mesmo `if` contra o −0,0).
	if combate_direcional != null:
		var avanco := combate_direcional.impulso_do_quadro()
		if avanco != Vector3.ZERO:
			velocity += avanco
	var velocidade_y_antes_do_pouso := velocity.y
	# Relevo em blocos (22/10/2026): sobe meio bloco andando. Subiu = o passo horizontal
	# do quadro foi dado; o `move_and_slide` só cuida do vertical.
	if colisor_capsula and modo_na_agua.is_empty() and SubirDegrau.tentar(self, delta,
			(_colisor.shape as CapsuleShape3D).radius if _colisor.shape is CapsuleShape3D else 0.0):
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		velocity -= horizontal
		move_and_slide()
		velocity += horizontal
	else:
		move_and_slide()
	_mc_mov.registrar(velocity)
	if colisor_capsula:
		HurtboxDeCombate.sincronizar(self)   # hurtbox no lugar NESTE quadro (ver a classe)
	if _air_slam_active and is_on_floor():
		_finalizar_ataque_aereo()
	_impacto_de_queda.atualizar(self, is_on_floor(), velocidade_y_antes_do_pouso)
	_ecos_de_movimento.atualizar(delta, _char_model, ecos_de_movimento_ligados and _is_sprinting() and is_on_floor())
	_poeira_dos_pes.atualizar(delta, velocity, is_on_floor(),
		esquivando() or _parkour.escalando() or _parkour.correndo_na_parede() or _charging or _rapid_fire)
	
	if _fsm and _fsm.state and _fsm.state.name == "Stunned":
		if is_on_wall() and empurrao.length_squared() > 4.0:
			var col = get_slide_collision(0)
			if col:
				var normal = col.get_normal()
				var bounce_vel = empurrao.bounce(normal) * 0.8 # Conserva 80% do momento
				_vida._empurrao = bounce_vel
				print("💥 Wall Bounce! Momentum: ", bounce_vel)

## Posiciona o VFX de fôlego na frente da boca (segue cabeça + facing -Z) e regula
## a intensidade pela velocidade. Só "respira forte" correndo no chão.
func _update_breath() -> void:
	if _breath == null:
		return
	if _char_model and _head_node and is_instance_valid(_head_node):
		var yaw := _char_model.rotation.y
		var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)   # frente do projeto = -Z
		# À frente da boca (não atravessa o rosto) e um tico abaixo do centro da cabeça.
		_breath.global_position = _head_node.global_position + fwd * 0.28 + Vector3(0, -0.04, 0)
		_breath.rotation = Vector3(0, yaw, 0)   # local +Z = costas -> baforada vai p/ trás
	var planar := Vector2(velocity.x, velocity.z).length()
	var running := planar > 1.0 and is_on_floor() and not _is_climbing
	_breath.set_running(running)
	_breath.set_intensity(planar / SPEED)   # 1.0 = corrida normal, ~1.5 = sprint

## Chamado pelo braço elástico (GomuArm) quando o punho retorna ao corpo:
## dispara o tranco de recepção (chicote) na animação procedural.
func trigger_recovery_anim(slot: String = "Z") -> void:
	if _proc_anim:
		_proc_anim.trigger_recovery(slot)

# ---- Fase 8: DOMAR inimigo (botão direito) ----
# DESATIVADO por ora (Fase 9): muito conteúdo pendente (frutas/estilos). Código
# mantido; é só religar TAMING_ENABLED = true quando quiser retomar os companions.
const TAMING_ENABLED := false

# Raycast da câmera; se mirar um inimigo perto, pede a doma ao SERVIDOR (autoridade).
func _try_tame() -> void:
	if not TAMING_ENABLED or _cam == null:
		return
	var from := _cam.global_position
	var to := from + (-_cam.global_transform.basis.z) * 9.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var col = hit.get("collider")
	if col and col.is_in_group("enemy"):
		_request_tame(str(col.name))

func _request_tame(enemy_name: String) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_tame(enemy_name, str(name).to_int())
	else:
		_net_tame.rpc_id(1, enemy_name, str(name).to_int())

@rpc("any_peer", "reliable")
func _net_tame(enemy_name: String, owner_peer: int) -> void:
	if multiplayer.is_server():
		_do_tame(enemy_name, owner_peer)

func _do_tame(enemy_name: String, owner_peer: int) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.name == enemy_name and e.has_method("tame"):
			e.tame(owner_peer)
			return

## Player REMOTO (controlado por outro cliente): não simula física (a posição vem
## replicada). Só reproduz a animação a partir do estado replicado e vira o modelo
## pelo facing replicado, pra parecer vivo na tela dos outros.
func _remote_process(delta: float) -> void:
	if current_fruit_id in ["ope_ope", "rocket"] and multiplayer.is_server():
		var factor := HealthController.PENALIDADE_DANO if _vida.em_combate() else 1.0
		energy = minf(max_energy, energy + HealthController.regen_energia_por_s(
			max_energy, _vida.com_bonus_de_kill()) * factor * delta)
	# O servidor também costuma ver jogadores de clientes por este caminho;
	# portanto o relógio autoritativo do Corpo de Ferro não pode depender da
	# autoridade local.
	_corpo_de_ferro.atualizar(delta)
	# No servidor, os corpos dos clientes passam por este caminho. A trava da
	# fruta também precisa andar aqui, senão o servidor recusaria casts deles
	# para sempre depois do primeiro dano.
	if _fruit_damage_lock_timer > 0.0:
		_fruit_damage_lock_timer = maxf(_fruit_damage_lock_timer - delta, 0.0)
	velocity = net_velocity
	_agachar.aplicar(net_agachado)
	_buki_apontar_canhao()   # canhão-corpo da Buki acompanha o facing replicado
	if _char_model:
		_char_model.rotation.y = lerp_angle(_char_model.rotation.y, net_facing, 18.0 * delta)
	_arremesso.tick_remoto(delta, net_on_floor)
	_inclinar_no_wall_run(delta, net_parede_lado)
	_arremesso.apresentar(_char_model, delta)
	if _skel_anim:
		_skel_anim.update(net_velocity, net_on_floor, net_escalando, delta, false)
	elif _proc_anim:
		var charge_x := net_charge_progress if net_charge_pose == "mera_x_charge" else 0.0
		var pose_remota := _arremesso.pose_de_membros() if _arremesso.ativo() else net_charge_pose
		_proc_anim.parede_lado = net_parede_lado
		_proc_anim.subida_borda = net_subida
		_proc_anim.loco_inclinacao = net_inclinacao.x
		_proc_anim.acao_clipe = net_acao_clipe
		_proc_anim.acao_tempo = net_acao_tempo
		_proc_anim.loco_inclinacao_frente = net_inclinacao.y
		var vel_anim_remota := net_velocity
		if net_escalando:
			# A frente aponta para a parede: tira a pressão de contato (não é passo).
			var para_parede := RosaDosVentos.frente(net_facing)
			vel_anim_remota -= para_parede * net_velocity.dot(para_parede)
		_proc_anim.update(vel_anim_remota, net_on_floor, net_escalando, delta, _pitch, false,
			net_charge_pose != "", "", "agachar" if net_agachado else net_parkour, false, 0.0, 0.0, -1, charge_x, pose_remota)
	_poeira_dos_pes.atualizar(delta, net_velocity, net_on_floor, false)
	_impacto_de_queda.atualizar(self, net_on_floor, net_velocity.y)
	_ecos_de_movimento.atualizar(delta, _char_model, ecos_de_movimento_ligados and net_on_floor and Vector2(net_velocity.x, net_velocity.z).length() > SPEED * 1.35)

# Corpo de Ferro (F): o pedido do cliente nunca escreve imunidade diretamente.
# O servidor valida dono + recarga e só então replica o efeito de um segundo.
func _pedir_corpo_de_ferro() -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_corpo_de_ferro()
	else:
		_net_corpo_de_ferro_req.rpc_id(1)

@rpc("any_peer", "reliable")
func _net_corpo_de_ferro_req() -> void:
	if not multiplayer.is_server():
		return
	var remetente := multiplayer.get_remote_sender_id()
	if remetente != 0 and remetente != get_multiplayer_authority():
		return
	_do_server_corpo_de_ferro()

func _do_server_corpo_de_ferro() -> void:
	if not _corpo_de_ferro.pronto():
		return
	if multiplayer.has_multiplayer_peer():
		_net_play_corpo_de_ferro.rpc()
	else:
		_net_play_corpo_de_ferro()

@rpc("any_peer", "call_local", "reliable")
func _net_play_corpo_de_ferro() -> void:
	if multiplayer.has_multiplayer_peer():
		var remetente := multiplayer.get_remote_sender_id()
		if remetente != 0 and remetente != 1:
			return
	_corpo_de_ferro.ativar_confirmado()
	print("🛡️ Corpo de Ferro: imune por 1 s. Recarga: 30 s.")

func limpar_silencio_de_corpo_de_ferro() -> void:
	_cast.limpar_silencio()

func set_character(cid: String) -> void:
	# Coage aqui também: abaixo o `match cid` escolhe a fruta inicial, e ele
	# precisa ver o personagem que de fato foi carregado.
	if not ELENCO_LIBERADO.has(cid):
		print("[Personagem] '", cid, "' está trancado — usando ", ELENCO_LIBERADO[0])
		cid = ELENCO_LIBERADO[0]
	_setup_character_model(cid)
	match cid:
		"ace":
			current_fruit_id = "mera_mera"
			combat_mode = "fruit"
		"buggy":
			current_fruit_id = "bara_bara"
			combat_mode = "fruit"
		"nami":
			current_fruit_id = "goro_goro"
			combat_mode = "fruit"
		"blackbeard":
			current_fruit_id = "yami_yami"
			combat_mode = "fruit"
		"crocodile":
			current_fruit_id = "suna_suna"
			combat_mode = "fruit"
		"base", _:
			current_fruit_id = "gomu_gomu"
			combat_mode = "fruit"
	var active_style: String = STYLES_LIST[current_style_idx] if current_style_idx < STYLES_LIST.size() else ""
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_combat_mode"):
		hud.update_combat_mode(combat_mode, active_style, current_fruit_id)

# TROCA DE PERSONAGEM — política aqui, montagem no rig.
#
# A GUARDA DA TRAVA DE ELENCO fica NESTE ponto, e não no `set_character`, porque
# aqui é por onde TODOS passam: menu, rede, e principalmente a troca automática
# de aparência do `equip_fruit()` (o Main equipa suna_suna ao nascer, o que
# virava Crocodile mesmo com o elenco trancado). Quem pode ser carregado é regra
# de JOGO — por isso não desceu para o componente, que monta o que mandarem.
# ============================================================================
#  COR DO JOGADOR — identificação visual em partida online.
# ============================================================================
#
#  ⚠️ A COR VEM DO DADO DE SPAWN, e isso é a parte que importa. Ela poderia ser
#  sorteada aqui, ou derivada de `hash(peer_id)` — e as duas dariam cores
#  DIFERENTES EM CADA MÁQUINA, porque cada peer sortearia por conta própria.
#  Quem manda é o servidor: ele escolhe o índice em `Main._spawn_player_for`, e o
#  `MultiplayerSpawner` replica o dicionário de spawn inteiro. Todo mundo monta o
#  mesmo corpo com a mesma cor, sem RPC novo e sem propriedade replicada a mais.
## A lista mora em `src/customizacao/Paleta.gd` — dado puro, sem dependência de
## autoload. Aqui fica só o apelido, para os usos existentes não mudarem.
## Ver o cabeçalho do `Paleta.gd` para o porquê da mudança.
const CORES := Paleta.CORES

## Índice em `CORES`. −1 = sem cor atribuída (singleplayer, testes) — aí o
## personagem fica com a aparência original.
var cor_idx: int = -1

## O colisor e o tamanho de referência dele. Guardados porque o Gigante os
## redimensiona — ver `_aplicar_escala_de_raca`.
const COLISOR_BASE := Vector3(1.0, 1.6, 1.0)
## Raio da cápsula do Modo História: 0,5 m = a meia largura da caixa antiga. Assim dois
## lutadores frente a frente param à MESMA distância (1,0 m) para a qual o combate
## direcional foi afinado — com 0,4 eles chegavam a 0,8 m, quem processava primeiro
## avançava e acertava antes, e a troca simultânea de jabs deixou de existir
## (test_contato_historia, 01/10/2026). Sobe beirada de ~15 cm (r × (1 − cos 45°)).
const RAIO_DA_CAPSULA := 0.5

# ---------------------------------------------------------------- ENCHENTE
# Eliminado pela água no fim da rodada: o corpo continua na arena (afundando),
# mas não responde a mais nada até o pódio. Não é o mesmo que "morrer": morrer
# respawna, e a enchente PRECISA que os mortos fiquem mortos, senão ela nunca
# termina — a condição de fim é justamente não sobrar ninguém de pé.
var _eliminado := false
var _colisor: CollisionShape3D = null
var _escala_base_do_modelo: Vector3 = Vector3.ONE

func nome_da_cor() -> String:
	return str(CORES[cor_idx]["nome"]) if cor_idx >= 0 and cor_idx < CORES.size() else "original"

## Chamada pelo `Main` no spawn. Guarda e pinta.
func aplicar_cor_do_jogador(idx: int) -> void:
	cor_idx = idx
	_tingir_modelo()

## Pinta o corpo. Precisa rodar DE NOVO a cada troca de personagem: `_rig.montar`
## constrói um modelo novo e o anterior (com a tinta) é descartado.
##
## ⚠️ Usa `material_override`, o mesmo caminho do `AutoDummy._recolor_model` —
## é o precedente do projeto para "este corpo é daquele time". Como ele cobre
## TODAS as malhas do modelo, uma arma da Buki que já esteja na mão no momento da
## pintura também é tingida; ela volta ao normal no próximo saque, que reconstrói
## o visual. Não vale complicar por isso enquanto for só cosmético.
## O TAMANHO DA RAÇA (Gigante). Decisão do dono, 2026-08-29: o gigante não é só
## um boneco maior — cresce a CÁPSULA e a CÂMERA junto.
##
## ⚠️ OS TRÊS OU NENHUM. Só o modelo cresceria e o gigante passaria por vãos em
## que visualmente não cabe, e levaria dano no ar em volta do corpo; só a
## cápsula e ele empacaria em porta nenhuma sem motivo visível. A câmera entra
## porque a altura do pivô é fixa em metros: sem ajustar, o gigante enxerga a
## partir do próprio peito.
## O tamanho do corpo = o da RAÇA (Gigante) × o da FORMA do Mine Piece (`scale pehkui:height`, formas gigantes do mod).
var escala_forma := 1.0
## Altura medida (19/11/2026) dos piratas e marinheiros básicos do Modo História (`mp_pirate_pirate1`, `mp_bandit`: 2,05 m; o `mp_marine` tem 2,14 m com o capacete).
## O jogador é normalizado para `PlayerRig.CHAR_TARGET_H` (1,5 m) — 27 % menor que eles. GATILHO: se um inimigo básico novo vier com outra altura, medir de novo.
const ALTURA_DOS_INIMIGOS_BASICOS := 2.05
## Fator do MODO (1 = arena, que segue com os 1,5 m de todos os personagens). O Modo História o liga em `colocar_civil` para o jogador ter a altura dos inimigos.
var escala_de_modo := 1.0


func escala_do_corpo() -> float:
	return Racas.escala_de(Visual.raca) * escala_forma * escala_de_modo


## Escala que iguala o corpo do jogador à dos inimigos básicos (modelo, cápsula, hurtbox e câmera crescem juntos).
static func escala_para_altura_dos_inimigos() -> float:
	return ALTURA_DOS_INIMIGOS_BASICOS / PlayerRig.CHAR_TARGET_H


## Pehkui `height`/`width` do mod. O corpo do jogador cresce por igual (cápsula e hurtbox são uniformes), então manda o
## `height`; o `width` só entra na caixa que as procedures leem (`McEntidade.getBbWidth`).
func definir_escala_de_forma(altura: float, _largura: float) -> void:
	escala_forma = clampf(altura, 0.1, 16.0)
	_aplicar_escala_de_raca()


func _aplicar_escala_de_raca() -> void:
	_agachar.cancelar()
	var e := escala_do_corpo()
	if _char_model != null and is_instance_valid(_char_model):
		_char_model.scale = _escala_base_do_modelo * e
	if _colisor != null and is_instance_valid(_colisor):
		var forma := _colisor.shape as BoxShape3D
		if forma != null:
			forma.size = COLISOR_BASE * e
		var capsula := _colisor.shape as CapsuleShape3D
		if capsula != null:
			capsula.radius = RAIO_DA_CAPSULA * (e / escala_de_modo)      # a LARGURA da cápsula não engorda com o modo: vãos e portas do mapa seguem os de antes
			capsula.height = COLISOR_BASE.y * e
			HurtboxDeCombate.redimensionar(self, COLISOR_BASE * e, (COLISOR_BASE.y * (e - 1.0)) * 0.5)
		# A cápsula cresce a partir do centro, então o corpo afundaria meio
		# tamanho no chão sem subir o colisor junto.
		_colisor.position.y = (COLISOR_BASE.y * (e - 1.0)) * 0.5
	if _camera != null and is_instance_valid(_camera):
		_camera.definir_escala(e)


func _tingir_modelo() -> void:
	if is_instance_valid(_char_model) and _char_model.get_meta("preserve_original_materials", false):
		return
	if cor_idx < 0 or cor_idx >= CORES.size():
		return
	var modelo := _char_model
	if modelo == null or not is_instance_valid(modelo):
		return

	# ⚠️ A ESCOLHA DO JOGADOR VENCE A COR DE TIME QUANDO NÃO HÁ TIME (2026-08-29).
	#
	# Relato do dono: "ao logar a cor se torna automaticamente azul". No spawn o
	# `Main` dá a cada peer uma cor da paleta, e o peer 1 — o único que existe no
	# singleplayer — recebe a PRIMEIRA, que é azul. Sozinho no mundo não há quem
	# distinguir, então a cor de time não está resolvendo nada e só apaga o que
	# o jogador escolheu na Customização.
	#
	# Em partida com gente, a cor de time continua mandando: é ela que diz quem
	# é quem, e isso vale mais do que a preferência estética de cada um.
	if Visual.cor_do_corpo().a > 0.0 \
			and not (multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0):
		return

	var c: Color = CORES[cor_idx]["cor"]
	var malhas: Array = []
	FxUtil._collect_meshes(modelo, malhas)
	for m in malhas:
		if not (m is MeshInstance3D):
			continue
		# ⚠️ A COR DE TIME É DO CORPO, NÃO DO GUARDA-ROUPA. Sem esta linha o
		# `material_override` cobria TAMBÉM chapéu, cabelo e máscara — e como
		# ele vence o override de superfície com que os acessórios são pintados,
		# a cor original deles continuava lá embaixo, intacta e invisível. Era a
		# outra metade do relato: "a cor do acessório também fica azul".
		#
		# O código já sabia disso e tinha deixado passar: a nota acima dizia que
		# uma arma da Buki na mão saía tingida junto, e que "não vale complicar
		# enquanto for só cosmético". Com a Customização ligada ao mundo, passou
		# a valer — o jogador escolhe o cabelo e recebe outro.
		if Visual.e_adorno(m):
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		# Preto puro some contra a sombra; um mínimo de brilho próprio mantém a
		# silhueta legível sem clarear a cor.
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 0.35
		(m as MeshInstance3D).material_override = mat

func _setup_character_model(cid: String) -> void:
	var bara := BARA.action_for(self)
	if bara != null: bara.finish()
	BARA_NET.cleanup(self)
	# ⚠️ SAÍDA POR TROCA DE PERSONAGEM. `_rig.montar` constrói um modelo NOVO: as
	# malhas pintadas e o nó do chapéu vão embora com o antigo. Desligar antes
	# evita o chapéu órfão e faz o `_gear2` reapontar para o rig novo.
	if _gear2:
		_gear2.desativar()
	if not ELENCO_LIBERADO.has(cid):
		cid = ELENCO_LIBERADO[0]

	var reequipar_yoru := combat_mode == "sword"
	_cancel_yoru_action("rig")
	if is_instance_valid(_yoru):
		_toggle_yoru_visual()
	_buki.esquecer_visual()   # o modelo antigo levou as armas embora
	_rig.montar(cid)
	if reequipar_yoru:
		_toggle_yoru_visual()

	# Fôlego (VFX): é do PLAYER, não do rig — sobrevive à troca de personagem e é
	# reaproveitado. Só o voxel tem (o skinnado saía pelo `return` antes deste
	# ponto no código antigo; a condição abaixo preserva isso exatamente).
	if not _rig.skinnado() and _breath == null:
		_breath = load("res://VFX/BreathVFX.tscn").instantiate()
		add_child(_breath)   # filho do Player (sem a escala do rig)

	# O rig acabou de ser reconstruído: a tinta do modelo anterior foi embora com
	# ele. Repintar aqui é o que faz a cor sobreviver à troca de personagem.
	_tingir_modelo()

	# ⚠️ A CUSTOMIZAÇÃO ENTRA NO MUNDO AQUI (2026-08-29).
	#
	# Até agora o menu de Customização era um efeito colateral da tela: o
	# jogador montava o personagem, entrava na partida e jogava com o boneco
	# padrão. `Visual.aplicar` é a MESMA função que monta a prévia — é isso que
	# faz o que ele viu no menu ser o que ele recebe no jogo, em vez de dois
	# caminhos que podem divergir.
	#
	# DEPOIS do `_tingir_modelo`, e com `preservar_cor_do_jogo`: a cor de time
	# pinta TODAS as malhas, então rodar antes deixaria chapéu e cabelo da cor
	# do time; e sem o preservar, um jogador sem cor escolhida teria a tinta do
	# time apagada.
	#
	# Roda a cada remontagem do rig (troca de personagem, Gear 2) porque o
	# modelo novo nasce limpo — a peça equipada morreu com o modelo anterior.
	Visual.carregar_uma_vez()
	# A escala do rig recém-montado, ANTES de a raça mexer nela: é sobre esta
	# que o Gigante multiplica. Ler depois pegaria a escala já multiplicada e
	# cada remontagem deixaria o personagem maior que a anterior.
	_escala_base_do_modelo = _char_model.scale
	Visual.aplicar(_char_model, true)
	_aplicar_escala_de_raca()

# PRESENTATION da arma empunhada — roda em TODOS os peers (chamada de dentro de
# `_fire_skill` e do `_net_buki_guardar`), então o adversário vê a arma na mão
# e vê o corpo virar canhão. "" = guardar tudo.
func _buki_mostrar_arma(slot: String) -> void:
	_buki.mostrar_arma(slot)

# O corpo some em TRÊS casos: 1ª pessoa (já era), canhão-corpo da Buki (X) e a forma
# de foguete da Rocket (F no Modo História). Ficam no mesmo lugar porque brigavam: o
# `_apply_perspective` reacendia o corpo no meio da transformação.
func _atualizar_visibilidade_corpo() -> void:
	if _char_model == null:
		return
	var pode_ver_corpo := (_camera == null or not _camera.em_primeira_pessoa()) \
			and _buki_visual != "X" and not _voo.forma_de_foguete()
	_char_model.visible = pode_ver_corpo and not get_meta("phoenix_transformado", false) and not get_meta("magu_cao_ativo", false) and not get_meta("goro_mp_invisivel", false) and not get_meta("mine_piece_invisivel", false) and not get_meta(FormaZoan.META_ATIVA, false) and (not _invisivel or _is_authority)
	_aplicar_transparencia_invisivel()

func iniciar_invisibilidade() -> void:
	# Z é alternável: a segunda pressão encerra a camuflagem voluntariamente.
	if _invisivel:
		revelar_invisibilidade()
		return
	if energy <= 0.0 or current_fruit_id != "suke_suke": return
	if multiplayer.has_multiplayer_peer():
		_pedir_invisibilidade.rpc_id(NetworkConfig.SERVER_ID)
	else:
		_aplicar_invisibilidade(true)

## A Camuflagem Transparente (Suke Suke Z) está ligada? Consultado pela IA dos inimigos (`CerebroMinePiece`): antes disto a
## invisibilidade só escondia o modelo e todo inimigo continuava a perseguir o jogador (defeito achado em 15/11/2026).
func esta_camuflado() -> bool:
	return _invisivel

func revelar_invisibilidade() -> void:
	if not _invisivel: return
	if multiplayer.has_multiplayer_peer():
		_pedir_revelar_invisibilidade.rpc_id(NetworkConfig.SERVER_ID)
	else:
		_aplicar_invisibilidade(false)

@rpc("any_peer", "call_local", "reliable")
func _pedir_invisibilidade() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return
	var remetente := multiplayer.get_remote_sender_id()
	if multiplayer.has_multiplayer_peer() and remetente != 0 and remetente != get_multiplayer_authority(): return
	_definir_invisibilidade.rpc(true)

@rpc("any_peer", "call_local", "reliable")
func _pedir_revelar_invisibilidade() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return
	var remetente := multiplayer.get_remote_sender_id()
	if multiplayer.has_multiplayer_peer() and remetente != 0 and remetente != get_multiplayer_authority(): return
	_definir_invisibilidade.rpc(false)

@rpc("authority", "call_local", "reliable")
func _definir_invisibilidade(ativa: bool) -> void:
	_aplicar_invisibilidade(ativa)

func _aplicar_invisibilidade(ativa: bool) -> void:
	if _invisivel == ativa: return
	_invisivel = ativa
	if not ativa:
		trigger_skill_cooldown("Z") # os 10 s começam SOMENTE ao revelar
	_atualizar_visibilidade_corpo()

func _aplicar_transparencia_invisivel() -> void:
	if _char_model == null or not _is_authority: return
	for m in _char_model.find_children("*", "MeshInstance3D", true, false):
		var mesh := m as MeshInstance3D
		if mesh == null: continue
		if _invisivel:
			if not _materiais_antes_da_invisibilidade.has(mesh):
				_materiais_antes_da_invisibilidade[mesh] = mesh.material_override
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.70, 0.88, 1.0, 0.28)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.material_override = mat
		elif _materiais_antes_da_invisibilidade.has(mesh):
			mesh.material_override = _materiais_antes_da_invisibilidade[mesh]
	if not _invisivel:
		_materiais_antes_da_invisibilidade.clear()

# ---------------------------------------------------------------- combate ---
func _registrar_trava_de_fruta_por_dano(amount: float) -> void:
	if amount > 0.0:
		_fruit_damage_lock_timer = TRAVA_FRUTA_APOS_DANO

func fruta_bloqueada_por_dano() -> bool:
	return combat_mode == "fruit" and _fruit_damage_lock_timer > 0.0

## ⚠️ A JANELA QUE O COUNTER HIT PUNE. `true` do clique até a hitbox nascer —
## quando o corpo já está comprometido com um golpe e ainda não tem como acertar.
## Serve para o CONTEXTUAL e para o M1, porque `MeleeController.fase()` já
## responde pelos dois com o mesmo relógio.
##
## É consultado pelo SERVIDOR, no instante do impacto e antes de o dano correr —
## depois do dano o golpe do alvo já foi interrompido e a resposta seria sempre
## falsa (ver `DamageZone.antes_do_acerto`).
func em_startup_de_ataque() -> bool:
	if combate_direcional != null:
		return combate_direcional.em_preparo()
	return _melee != null and _melee.fase() == "startup"


## A raiz visível do personagem (a que gira com o olhar e contém o rig). Pública
## para o combate direcional aplicar pose sem ler campo privado.
func modelo_visual() -> Node3D:
	return _char_model


## Clipe de GOLPE do combate direcional (Epic Fight): toca o clipe assado no corpo inteiro; o executor decide fases e dano.
var _clipe_de_golpe := false


## Giro máximo do quadril (yaw) num golpe de clipe do Epic Fight: ~52° (o montante girava ~115° e parecia atacar para trás): ver `ProceduralAnimator.limite_do_giro_do_quadril`.
const GIRO_MAXIMO_DO_QUADRIL_NO_GOLPE := 0.0        # 0 = sem limite: o limite de 52° (primeira tentativa) NÃO corrigia o montante; quem corrige é `RumoDosGolpes`
var giro_maximo_do_quadril_no_golpe := GIRO_MAXIMO_DO_QUADRIL_NO_GOLPE      # variável para o teste de direção comparar com/sem o limite (0 = sem limite)
## Inclinação máxima do tronco num golpe de clipe do Epic Fight (rad ≈ 29°; era 0,7 ≈ 40° — o dono pediu o tronco mais em pé, 12/11/2026): ver `ProceduralAnimator.limite_da_dobra_do_tronco`.
const DOBRA_MAXIMA_DO_TRONCO_NO_GOLPE := 0.5


func tocar_clipe_de_golpe(caminho: String, ate := -1.0, velocidade := 1.0) -> void:
	if _proc_anim == null or not ResourceLoader.exists(caminho):
		return
	var a := load(caminho) as Animation
	if a != null:
		# O golpe do clipe (Epic Fight) sai para onde a MIRA aponta: o corpo vira para ela JÁ, no primeiro quadro. Os preparos do mod são de 0,05–0,2 s e o teto
		# de giro do estilo base (360°/s no preparo) não deixava o corpo chegar: com a câmera virada o avanço e o corte saíam de lado ou para trás.
		if _char_model != null:
			_char_model.rotation.y = _yaw
			_loco_chao.rumo = _yaw
		_proc_anim.play_baked(a, velocidade, 0.0, "", ate)     # só até o fim do golpe: o mod corta o clipe na recuperação
		_proc_anim.movimento_do_clipe = true                # o avanço do corpo vem do clipe (`Corpo:deslocamento`); `play_baked` o desliga para os outros clipes
		_proc_anim.limite_da_dobra_do_tronco = DOBRA_MAXIMA_DO_TRONCO_NO_GOLPE
		_proc_anim.limite_do_giro_do_quadril = giro_maximo_do_quadril_no_golpe
		_proc_anim.desvio_de_rumo_do_torso = RumoDosGolpes.desvio_do_clipe(caminho)
		_clipe_de_golpe = true


func parar_clipe_de_golpe() -> void:
	if _proc_anim != null:
		_proc_anim.movimento_do_clipe = false
	if _clipe_de_golpe and _proc_anim != null:
		_proc_anim.play_baked(null)
	_clipe_de_golpe = false


## Um clipe de ação (roll do Q, deslize, bloco Animação do Builder) está dirigindo o
## corpo inteiro. Pública para o combate direcional não pôr a guarda por cima dele.
## No Modo História o E é do INVENTÁRIO (e da interação): a HUD da história tem `mochila()`. Na arena (outra HUD) o E segue ligando a Observação.
func _e_e_do_inventario() -> bool:
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	return hud != null and hud.has_method("mochila")


## O jogador levou dano há pouco (janela de combate do `HealthController`). Público para a `ZonaDeCombate`.
func em_combate() -> bool:
	return _vida.em_combate()


func clipe_de_acao_ativo() -> bool:
	return _proc_anim != null and _proc_anim.acao_clipe != ""


## O corpo está solto para um golpe? Mesmas travas do `_consume_input` (arremesso,
## derrubado, congelado) mais atordoado, morto e preso ao parkour de parede. É API pública porque o adaptador
## do combate direcional (`AtorJogador`) não lê campo privado do Player.
##
## ⚠️ Duplica três condições do `_consume_input` DE PROPÓSITO: aquele é caminho da
## arena, e mexer nele para compartilhar mudaria arquivo alheio sem ganho de
## comportamento. GATILHO: se uma quarta trava entrar num dos dois, unificar.
##
## `contar_atordoamento = false` ignora só o "Stunned": o golpe que trocou dano no
## ATIVO segue até o fim (plano, §7.1), e todo dano deste corpo atordoa.
func corpo_livre_para_golpe(contar_atordoamento := true) -> bool:
	if esta_capturado_pelo_vento():
		return false
	if is_instance_valid(navegacao):
		return false
	if is_instance_valid(montaria):
		return false
	if _arremesso.ativo():
		return false
	if get_meta("custom_pose", "") == "knockdown" or get_meta("is_frozen", false):
		return false
	if contar_atordoamento and _fsm and _fsm.state and _fsm.state.name == "Stunned":
		return false
	# Escalando ou correndo na parede o corpo é do parkour: agarrar a parede no meio
	# do golpe o encerra, e não se começa golpe grudado nela.
	if _parkour.assumiu():
		return false
	return health > 0.0


func take_damage(amount: float, attacker_pos: Vector3 = Vector3.ZERO, base_knockback: Vector3 = Vector3.ZERO, hitstun_duration: float = 0.3) -> void:
	amount *= DanoDaHistoria.fator_recebido      # Modo História: fator próprio do dano recebido (a ponta que causa está em `CombatResolver.aplicar`)
	amount /= maxf(1.0, float(get_meta("resistencia_de_forma", 1.0)))      # fruta Zoan transformada (Ushi Ushi: ×1,5): o dano recebido cai por esse fator
	if has_meta("nivel_historia"):
		amount = preload("res://src/historia/atributos_mine_piece.gd").dano_recebido(amount, int(get_meta("nivel_historia")))
	if _invisivel:
		revelar_invisibilidade()
	# `in_black_hole` entrou aqui em 2026-08-11: o Black Hole da Yami é CONTROLE
	# PURO — puxa, afunda e silencia, e quem mata é o buraco do mapa depois.
	# `TrainingDummy.gd:64` e `disabled/enemies/Enemy.gd` já recusavam dano de
	# quem está preso; só o jogador não recusava, e a mesma habilidade tinha
	# regra diferente dependendo de quem caía nela.
	# ⚠️ `iron_body_active` SAIU DESTA LISTA em 2026-08-31. Era aqui que a
	# invulnerabilidade total do Corpo de Ferro morava — a função retornava e o
	# golpe sumia inteiro. O dono pediu que a janela passasse a "cortar os danos
	# pela metade", e meia imunidade não cabe numa guarda que só sabe dizer
	# "sim ou não": o corte agora acontece logo abaixo, sobre o `amount`.
	if get_meta("magu_cao_ativo", false) or get_meta("giro_espada_ativo", false) or get_meta("damage_immune", false) or get_meta("kira_investida_imune", false) or get_meta("custom_pose", "") == "hibashira" or get_meta("in_black_hole", false):
		print("🛡️ DANO E KNOCKBACK BLOQUEADOS! O usuário está IMUNE a danos durante a habilidade!")
		return
	var empurra := true
	# Eventos do Forge do mod (guarda, resistência, Haki de Armamento…) também protegem o JOGADOR (item 4 da auditoria, 09/11/2026).
	var jogador_do_mod := get_node_or_null("JogadorDoMod") as JogadorDoMod
	if jogador_do_mod != null:
		var quem: Node3D = null
		if has_meta("autor_do_dano") and is_instance_id_valid(int(get_meta("autor_do_dano"))):
			quem = instance_from_id(int(get_meta("autor_do_dano"))) as Node3D
		amount = jogador_do_mod.ao_receber_dano(amount, quem)
		if amount < 0.0:
			return
		amount = jogador_do_mod.dano_final(amount)
		if amount <= 0.0:
			return
	# Minecraft: 0,5 s de invulnerabilidade depois de apanhar; golpe maior nesse tempo tira só a diferença, sem empurrão
	# (`KnockbackMinecraft.filtrar`).
	# ⚠️ DEPOIS dos eventos do mod (10/11/2026). Antes ele rodava ANTES: o golpe de um personagem do East Blue chega como
	# `damage_curse` de ~19; o filtro o registrava como "último golpe" e abria a janela de 0,5 s; o mod então cancela esse golpe
	# e REAPLICA um dano menor (~1, `damage_combat`) dentro do mesmo evento — e o filtro o recusava ("menor ou igual ao último").
	# Resultado: o empurrão e os efeitos do mod aplicavam, a vida nunca descia. Filtrando o dano FINAL, só o que realmente
	# vai à vida conta para a janela.
	if knockback_minecraft != null:
		var filtro := knockback_minecraft.filtrar(amount)
		if float(filtro["dano"]) <= 0.0:
			return
		amount = float(filtro["dano"])
		empurra = bool(filtro["empurra"])
	_cancel_yoru_action("damage")
	_registrar_trava_de_fruta_por_dano(amount)

	# ⚠️ CORPO DE FERRO CORTA O DANO PELA METADE (2026-08-31). Antes a janela dava
	# invulnerabilidade e o golpe sumia inteiro; agora ele chega, valendo metade.
	#
	# O corte é AQUI, no começo do funil, e não só na subtração da vida: o
	# `amount` segue para o feedback (número que sobe na tela) e para o RPC que
	# leva a vida ao dono. Cortar mais adiante mostraria ao jogador um número que
	# não foi o que ele tomou.
	if get_meta("iron_body_active", false):
		amount *= IronBodyController.FATOR_DE_DANO

	# 1. INTERRUPÇÃO DE ATAQUE SOBRE DANO
	#
	# ⚠️ O Charge-up é a EXCEÇÃO: nele o dano LIBERA o golpe com a carga que
	# houver, em vez de cancelar. Por isso ele vem ANTES do
	# `interrupt_casting`, que cancelaria. Decisão do dono — ver
	# docs/PEDIDO_2026-08-12.md.
	_cast.liberar_por_dano()
	var interrompeu_cast := SkillSystem.interrupt_casting(self)
	# Z nao usa `_charging` porque permite movimento. Sem esta chamada sincrona,
	# ele nunca passaria pelo portao que aborta cargas e continuaria causando dano
	# depois de o usuario entrar em hitstun. X/V tambem precisam avisar o servidor
	# antes que um key-up atrasado tente concluir a acao interrompida.
	if interrompeu_cast and _cast.acao_pacifista_ativa():
		_cast.abortar()

	if _animator:
		_animator.trigger_damage()
	elif _skel_anim:
		_skel_anim.play_one_shot("damage")

	var morreu := _vida.sofrer_dano(amount)
	_feedback_de_dano(amount, hitstun_duration)

	# ⚠️ A VIDA É DO SERVIDOR — e ela precisa ATRAVESSAR a rede.
	#
	# A `DamageZone` roda no servidor, então este `take_damage` roda na cópia que
	# o servidor tem da vítima. Sem avisar o dono, cada lado fica com uma vida
	# própria e elas nunca se falam: medido em 2026-08-12, a vítima morria com a
	# BARRA CHEIA na tela dela — sem flash, sem som e sem número de dano.
	#
	# Por que RPC e não `MultiplayerSynchronizer`: o synchronizer replica DA
	# AUTORIDADE para os outros, e a autoridade do corpo é o CLIENTE. Pôr `health`
	# lá deixaria a vida nas mãos dele — cliente adulterado ficaria imortal, e o
	# dano que o servidor aplica seria sobrescrito no quadro seguinte.
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		net_vida_do_servidor.rpc(_vida.vida, amount)

	# 2. KNOCKBACK ESCALADO E MODIFICADO POR AR E MOVIMENTO
	# (No estilo Minecraft o empurrão sai de quem bateu mesmo com `base_knockback` zero.)
	var tem_empurrao := base_knockback.length() > 0.1 or (knockback_minecraft != null and attacker_pos != Vector3.ZERO)
	if empurra and tem_empurrao:
		# ⚠️ QUEM EMPURRA É O DONO DO CORPO, não quem calculou o dano.
		#
		# A `DamageZone` roda no SERVIDOR, então este `take_damage` roda na cópia
		# que o servidor tem da vítima. Se a vítima for de outro peer, mexer em
		# `velocity` aqui não vale nada: no quadro seguinte a replicação traz a
		# posição do dono e sobrescreve. Era por isso que ninguém tomava empurrão
		# em partida com dois PCs — e em um-jogador funcionava, porque lá o
		# servidor É o dono.
		#
		# Mando o knockback CRU, não o calculado: as duas regras que o modelam —
		# dobrar no ar e resistir andando contra — dependem de `is_on_floor()` e
		# do TECLADO da vítima. No servidor, `Input.is_key_pressed` lê o teclado
		# do HOST, não o do jogador que apanhou. Quem tem esses dados é o dono.
		if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
			var dono := get_multiplayer_authority()
			if multiplayer.get_peers().has(dono):
				net_apply_knockback.rpc_id(dono, base_knockback)
			return
		_aplicar_knockback(base_knockback, attacker_pos)

	# Minecraft não congela quem apanha: o empurrão e o pulinho saem na hora. A pausa
	# de impacto zerava `velocity` e apagava o pulinho (vertical do empurrão).
	if knockback_minecraft == null:
		var hitstop_dur := clampf(amount * 0.003 + 0.06, 0.06, 0.16)
		_hitstop_timer = hitstop_dur
		velocity = Vector3.ZERO # Impact Frame Hold


	if morreu:
		die_and_respawn()

# Pisca vermelho, som de recepção e número flutuante. Roda em QUALQUER cópia que
# souber do dano — é o que faz o adversário te ver apanhar.
func _feedback_de_dano(amount: float, hitstun_duration: float = 0.3) -> void:
	_cancel_yoru_action("damage")
	FxUtil.flash_dano(_char_model)
	FxUtil.bleed(get_tree().current_scene, global_position + Vector3.UP * 1.2, int(maxf(4, amount / 5.0)))
	AudioFX.dano_do_jogador(get_tree().current_scene, global_position + Vector3.UP * 1.0)
	# ANIMAÇÃO DE RECEPÇÃO DE DANO (pedido do dono, 2026-08-14):
	# "vai ocorrer sempre que o jogador receber dano".
	# Fica AQUI, e não no `take_damage`, de propósito: este é o funil por onde
	# passa todo dano visível em QUALQUER cópia — o do servidor e o que chega por
	# `net_vida_do_servidor`. Pendurar no `take_damage` faria o adversário não ver
	# você apanhar, que é exatamente o bug do item 20.
	var dur_knockdown := get_meta("knockdown_dur", 0.0) as float
	if dur_knockdown > 0.0:
		RecepcaoDeDano.derrubar_com_animacao(self, dur_knockdown)
		remove_meta("knockdown_dur")
	else:
		RecepcaoDeDano.aplicar(self, hitstun_duration)
	# ⚠️ SÓ NA AUTORIDADE — e isto NÃO é otimização, é o bug B2 do §2.4 do plano.
	#
	# `_feedback_de_dano` roda em TODA cópia que sabe do dano (é o que faz o
	# adversário te ver apanhar, item 20). Mas quem TIRA do "Stunned" é o
	# `RecepcaoDeDano.tick` lá em cima, e ele fica ATRÁS do
	# `if not _is_authority: return`. Numa cópia remota o estado entraria e não
	# sairia nunca: stun eterno, visível só para os outros jogadores.
	#
	# Até 2026-08-25 isso era inofensivo por acidente — não existia nó "Stunned"
	# e a transição era um no-op calado. Criar o estado ACORDA o defeito, então
	# ele é fechado no mesmo movimento.
	#
	# Não custa nada visualmente: o tranco em tela é a pose do
	# `RecepcaoDeDano`, aplicada logo acima em todas as cópias. A FSM da cópia
	# remota não governa movimento nenhum (quem governa é `_remote_process`).
	#
	# ESCOPO: isto fecha a metade do B2 que esta frente acordou. A outra metade
	# — a corrida entre a escrita do estado e o reset — continua sendo trabalho
	# da frente de REDE (§7, Ordem 1, B1-B6).
	if _fsm and _is_authority:
		_fsm.transition_to("Stunned")
	FxUtil.damage_number(get_tree().current_scene, global_position + Vector3.UP * 1.7, amount, Color(1.0, 0.75, 0.2))
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("on_player_damaged"):
		hud.on_player_damaged(amount, health, max_health)
	print("💥 Dano Recebido: ", amount, " | HP Restante: ", health, "/", max_health)

# O SERVIDOR manda a vida nova para todos. `call_remote` de propósito: quem
# emitiu (o servidor) já aplicou e já deu o feedback — repetir aqui piscaria e
# tocaria som duas vezes na tela dele.
#
# `dano > 0` = foi pancada, então dá feedback. `dano = 0` = foi restauração
# (respawn), e aí só o número muda.
@rpc("any_peer", "call_remote", "reliable")
func net_vida_do_servidor(nova_vida: float, dano: float) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return                      # só o servidor manda na vida
	_vida.vida = nova_vida
	if dano > 0.0:
		_registrar_trava_de_fruta_por_dano(dano)
		_feedback_de_dano(dano)
		_cast.liberar_por_dano()
		SkillSystem.interrupt_casting(self) # Usa o hitstun padrão na cópia remota (ou poderíamos enviar pelo RPC também)

# O SERVIDOR premia quem matou: 30 s de regeneração acelerada.
#
# É `@rpc` porque a regeneração só roda na AUTORIDADE — premiar a cópia do
# servidor não teria efeito nenhum sobre a vida que o jogador vê.
@rpc("any_peer", "call_local", "reliable")
func premiar_kill() -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return                       # só o servidor decide quem matou
	_vida.premiar_kill()

# RESTAURA a vida na cópia AUTORITATIVA e avisa todo mundo.
#
# ⚠️ Isto existe porque o `net_force_respawn` é mandado com `rpc_id(peer)` — só o
# DONO executa. A cópia do servidor, que é justamente a que a `DamageZone`
# machuca, ficava em 0 PARA SEMPRE: medido, 96,6 s depois do respawn o hp
# autoritativo ainda era 0,0 de 2048. Efeito em jogo: depois da primeira morte,
# qualquer acerto matava o cliente na hora, pelo resto da rodada.
func restaurar_vida_no_servidor() -> void:
	_vida.restaurar()
	RecepcaoDeDano.limpar(self)
	# ⚠️ A recarga da Buki tem DOIS relógios: `_skill_cooldowns` no dono (zerado
	# no `net_force_respawn`) e `_srv_recarga_ate` na cópia do servidor. Zerar só
	# um deixaria o jogador vendo o slot livre e o servidor recusando em
	# silêncio — o sintoma "apertei e não aconteceu nada".
	_buki.esquecer_recargas_do_servidor()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		net_vida_do_servidor.rpc(_vida.vida, 0.0)

func esta_arremessado() -> bool:
	return _arremesso.ativo()

func esta_capturado_pelo_vento() -> bool:
	return has_meta("captura_vento") and is_instance_valid(get_meta("captura_vento"))

func iniciar_captura_vento(controlador: Node) -> void:
	set_meta("captura_vento", controlador)
	_cancel_yoru_action("wind_capture")
	_cast.abortar()
	_melee.cancelar_golpe()
	_parkour.cancelar()
	_voo.cancelar()
	_arremesso.cancelar(_char_model)
	_dash_t = 0.0
	_roll_t = 0.0
	_input_buffer.clear()
	velocity = Vector3.ZERO

func cancelar_captura_vento() -> void:
	var captura: Node = get_meta("captura_vento") if has_meta("captura_vento") else null
	if is_instance_valid(captura):
		captura.cancelar()

## Arremesso com derrubada, pedido pelo SERVIDOR (4º soco do Boss). Todas as
## cópias animam; só o dono do corpo aplica a velocidade (ver PlayerArremesso).
func receber_arremesso(impulso: Vector3) -> void:
	if not impulso.is_finite():
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		net_arremesso.rpc(impulso)
	elif not multiplayer.has_multiplayer_peer():
		net_arremesso(impulso)

@rpc("any_peer", "call_local", "reliable")
func net_arremesso(impulso: Vector3) -> void:
	if get_meta("magu_cao_ativo", false):
		return
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	_arremesso.iniciar(self, impulso, _is_authority, _char_model)

# Pedido do servidor para o DONO do corpo se empurrar. Só o servidor manda.
@rpc("any_peer", "call_local", "reliable")
func net_apply_knockback(base_knockback: Vector3) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	_aplicar_knockback(base_knockback)

# Aplica o empurrão. As REGRAS (dobrar no ar, resistir andando contra) e o
# número moram no `HealthController`; aqui só se entrega o contexto que é do
# Player — chão e mira — e se soma o componente VERTICAL, que a locomoção não
# reatribui.
func _aplicar_knockback(base_knockback: Vector3, atacante := Vector3.ZERO) -> void:
	if get_meta("magu_cao_ativo", false):
		return
	if knockback_minecraft != null:
		var pulinho := knockback_minecraft.empurrar(global_position, atacante, base_knockback, GRAVITY, is_on_floor())
		if pulinho > 0.0:
			velocity.y = pulinho
		return
	velocity.y += _vida.empurrar(base_knockback, is_on_floor(), _yaw)


# Porta de entrada da MORTE — chegam aqui os dois caminhos: vida zerada (a
# DamageZone, no servidor) e queda no vazio (SkillSystem.process_void_check).
#
# Quem decide é sempre o PLACAR, no servidor: ele conta a morte, resolve de quem
# é a kill e manda o dono do corpo respawnar. Num cliente puro esta função não
# faz nada de propósito — o servidor enxerga a queda pela `position` replicada e
# declara a morte de lá. Sem placar na árvore (testes isolados), respawna direto.
func die_and_respawn() -> void:
	cancelar_captura_vento()
	if knockback_minecraft != null:
		knockback_minecraft.cancelar()
	_agachar.cancelar()
	net_agachado = false
	_cancel_yoru_action("death")
	# ⚠️ SAÍDA POR MORTE. Sem isto o corpo renasce com a pele do Gear 2 e o
	# chapéu, sem o estado — e a transformação viraria permanente pela porta dos
	# fundos. É um dos quatro caminhos de saída listados no `gear2_controller`.
	if _gear2:
		_gear2.desativar()
	var caiu := global_position.y < Scoreboard.void_y_de(self)
	if is_instance_valid(navegacao):
		navegacao.sair(true)
	if is_instance_valid(montaria):
		montaria.desmontar(true)
	if ao_morrer.is_valid():
		if not morrendo:
			morrendo = true
			ao_morrer.call(self, caiu)
		return
	var placar := get_tree().get_first_node_in_group("scoreboard")
	if placar and placar.has_method("report_death"):
		placar.report_death(self, caiu)
	else:
		net_force_respawn()

## Topo da cabeça em coordenada de mundo. Sai do COLISOR, não do modelo: é o
## colisor que a raça escala (`forma.size = COLISOR_BASE * e`), então um gigante
## precisa de mais água para ficar coberto do que um humano — que é o que a
## palavra "completamente coberto" quer dizer.
func topo_da_cabeca() -> float:
	var alt: float = COLISOR_BASE.y
	if is_instance_valid(_colisor) and _colisor.shape is BoxShape3D:
		alt = (_colisor.shape as BoxShape3D).size.y
	elif is_instance_valid(_colisor) and _colisor.shape is CapsuleShape3D:
		alt = (_colisor.shape as CapsuleShape3D).height
	return global_position.y + alt * 0.5


## AFOGADO. Chamado pelo SERVIDOR no dono do corpo (mesmo motivo do respawn: o
## estado de quem não é autoridade seria sobrescrito no quadro seguinte).
@rpc("any_peer", "call_local", "reliable")
func net_eliminar() -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	if _eliminado:
		return
	cancelar_captura_vento()
	_cancel_yoru_action("death")
	_eliminado = true
	health = 0.0
	# Um cast preso trava o jogador para o resto da partida — a mesma armadilha
	# documentada no `net_force_respawn`, e aqui não há respawn para desfazê-la.
	_cast.abortar()
	clear_spawned_skills()
	set_meta("is_casting", false)
	if _tocar_morte_mixamo():
		pass
	elif _animator:
		_animator.trigger_death()
	elif _skel_anim:
		_skel_anim.play_one_shot("death")


# MORTE COM O CLIPE `dying` DO MIXAMO (04/11/2026, pedido do dono: "adicionar animação de morte").
# O clipe tem 5,8 s e é uma morte inteira: o personagem cambaleia até ~3 s e desaba entre 3,6 e
# 4,5 s, terminando deitado. Aqui se toca só a JANELA do tropeço até o corpo no chão e a pose
# FICA (não levanta). Rodando no tempo da sequência de morte do História (câmera lenta ×0,25), a
# janela é acelerada para a queda levar ~DURACAO_DA_QUEDA s de tela. Sem rig procedural ou sem o
# clipe, devolve false e vale a queda de sempre.
const CLIPE_DE_MORTE := "res://assets/animations/dying.res"
const MORTE_INICIO := 3.0
const MORTE_FIM := 4.9
const DURACAO_DA_QUEDA := 2.2          # segundos de TELA (tempo real) no Modo História
var _morte_y_base := 0.0
var _morte_corpo_baixado := false

func _tocar_morte_mixamo() -> bool:
	if _proc_anim == null or not ResourceLoader.exists(CLIPE_DE_MORTE):
		return false
	var clipe := load(CLIPE_DE_MORTE) as Animation
	if clipe == null:
		return false
	var fim := minf(MORTE_FIM, clipe.length)
	var escala := MorteDoJogador.ESCALA_DO_TEMPO if ao_morrer.is_valid() else 1.0
	var velocidade := (fim - MORTE_INICIO) / (DURACAO_DA_QUEDA * escala) if ao_morrer.is_valid() else 1.0
	_proc_anim.play_baked(clipe, velocidade, MORTE_INICIO, "", fim, true)
	if _char_model != null:
		_morte_y_base = _char_model.position.y
		_morte_corpo_baixado = true
	return true


# Corpo deitado pousa no chão: o clipe só gira os membros em torno do quadril, então o corpo
# deitado ficaria no ar à altura do quadril. Baixa o modelo até o ponto mais baixo tocar o pé da
# cápsula (cresce com a queda: em pé o ponto mais baixo JÁ é o pé e nada se mexe).
func _pousar_corpo_morto(delta: float) -> void:
	if not _morte_corpo_baixado or _char_model == null or _colisor == null:
		return
	var chao := global_position.y - (topo_da_cabeca() - global_position.y)   # pé da cápsula
	var mais_baixo := INF
	for no in _char_model.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		mais_baixo = minf(mais_baixo, (mi.global_transform * mi.get_aabb()).position.y)
	if mais_baixo == INF:
		return
	var folga := mais_baixo - chao
	if folga > 0.02:
		_char_model.position.y -= folga * clampf(delta * 10.0, 0.0, 1.0)


## Solta o clipe de morte e devolve o corpo à altura normal (respawn e reanimação do coração).
func _soltar_corpo_morto() -> void:
	if not _morte_corpo_baixado:
		return
	_morte_corpo_baixado = false
	if _proc_anim != null:
		_proc_anim.play_baked(null)
	if _char_model != null:
		_char_model.position.y = _morte_y_base


## O CORAÇÃO VOLTOU A BATER (04/11/2026, `ReanimacaoDoCoracao`): em vez de respawnar, o corpo se
## levanta onde caiu com `fracao` da vida máxima. Desfaz o que `net_eliminar` travou: controles,
## clipe de morte, postura. Só o Modo História chama (o servidor da arena nunca reanima).
func reviver_do_coracao(fracao: float) -> void:
	_soltar_corpo_morto()
	_eliminado = false
	if get_meta("morte_ja_animada", false):
		remove_meta("morte_ja_animada")
	health = max_health * clampf(fracao, 0.0, 1.0)
	morrendo = false
	set_meta("is_casting", false)
	if _animator:
		_animator.is_locked = false
		_animator.trigger_idle_after_revive()
	elif _skel_anim:
		_skel_anim.play_one_shot("idle")


# Respawn de verdade. Só o DONO do corpo pode se teleportar (quem não é
# autoridade tem a posição sobrescrita pela replicação no frame seguinte), por
# isso o servidor pede por RPC em vez de mover na marra.
@rpc("any_peer", "call_local", "reliable")
func net_force_respawn() -> void:
	# Só o servidor (peer 1) manda respawnar; 0 = chamada local, sem rede.
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	_agachar.cancelar()
	net_agachado = false
	cancelar_captura_vento()
	if is_instance_valid(navegacao):
		navegacao.sair(true)
	if is_instance_valid(montaria):
		montaria.desmontar(true)
	# Sair da enchente é o único caminho de volta: quem foi eliminado só volta a
	# responder no respawn do pódio.
	_cancel_yoru_action("respawn")
	_soltar_corpo_morto()
	_eliminado = false
	print("💀 MORTE REGISTRADA! Respawnando na plataforma...")
	if get_meta("morte_ja_animada", false):
		remove_meta("morte_ja_animada")           # a sequência da história já tocou a queda (não repetir no ponto novo)
	elif _animator:
		_animator.trigger_death()
	elif _skel_anim:
		_skel_anim.play_one_shot("death")

	# Se o jogador possuía uma fruta, devolve a fruta para a sua árvore
	if current_fruit_id != "":
		limpar_skills_em_todos()
		FruitNet.respawn(current_fruit_id)
		current_fruit_id = ""
		speed_multiplier = 1.0
		jump_multiplier = 1.0

	# Morreu de arma na mão: ela some (em todos os peers — este RPC é call_local)
	# e o slot entra em recarga como em qualquer outro abandono.
	_buki_guardar()
	_buki_mostrar_arma("")

	# ⚠️ MORRER TEM QUE ABORTAR O CAST — sem isso o jogo trava DE VERDADE.
	#
	# Relatado jogando em 2026-08-12 e reproduzido aqui: quem morre **segurando**
	# a tecla de uma skill fica com `_charging = true` e `is_casting = true` para
	# sempre. Duas consequências, as duas permanentes:
	#
	#   • `_slot_em_uso()` passa a devolver aquele slot eternamente, e o laço de
	#     recarga CONGELA todos os outros ("o contador trava e nunca recarrega");
	#   • `CastController.comecar()` sai no `if _carregando: return` — ou seja,
	#     NENHUM poder funciona mais, pelo resto da partida.
	#
	# O respawn devolvia vida, fruta e recarga, mas deixava o cast pendurado.
	_cast.abortar()
	# Efeitos de ESTILO tambem vivem neste contêiner. A limpeza antiga acontecia
	# apenas dentro do `if current_fruit_id`, então morrer sem fruta deixava C/V e
	# braços clonados ativos na vida seguinte.
	clear_spawned_skills()
	set_meta("is_casting", false)
	set_meta("active_skill", "")
	set_meta("px_skill_ativa", "")
	for px_meta in ["px_laser_ativo", "px_iron_rush_ativo", "px_lance_ativo",
			"px_tri_beam_ativo"]:
		set_meta(px_meta, false)
	set_meta("yami_black_hole_active", false)
	set_meta("yami_kurouzu_active", false)
	set_meta("is_frozen", false)
	remove_meta("custom_pose")
	_gura_rush_active = false
	_gura_grab_timer = 0.0
	_gura_rush_timer = 0.0
	if is_instance_valid(_gura_rush_target):
		_gura_rush_target.set_meta("is_frozen", false)
		_gura_rush_target = null
	_encerrar_bomu_rush()
	# timer removido
	_disparo.parar_rajada()
	_disparo.desligar_yami()

	# Volta a máquina de estados para o básico para destravar o jogador
	if _fsm:
		_fsm.transition_to("Idle")

	# MORRER ZERA AS RECARGAS (decisão do dono, 2026-08-12). Antes elas
	# atravessavam a morte — medido: cast de C (10 s), morte com 7,967 s
	# restantes, e a recarga seguia correndo. Como o respawn também devolve a
	# fruta, o jogador voltava sem poder nenhum E com o relógio andando no vazio.
	for slot_k in _fruit_cooldowns.keys():
		_fruit_cooldowns[slot_k] = 0.0
	for slot_k in _style_cooldowns.keys():
		_style_cooldowns[slot_k] = 0.0
	if _yoru_combat:
		_yoru_combat.restore_cooldowns({})
		_yoru_combat._penalty = 0.0
	_server_cast_next_ms.clear()
	_server_last_cast_token.clear()
	_server_proximo_golpe_ms = 0
	_intervalo_golpe = 0.0

	_vida.restaurar()
	_arremesso.cancelar(_char_model)
	RecepcaoDeDano.limpar(self)
	# Orçamento de dano também morre com o corpo. Um pente cujo teto já tinha
	# sido gasto sobreviveria ao respawn e a primeira arma sacada na vida nova
	# não machucaria ninguém — mesmo tipo de vazamento do item 23 (`is_casting`
	# pendurado depois da morte).
	encerrar_disparo()
	velocity = Vector3.ZERO
	global_position = ponto_de_renascimento   # arena: centro da plataforma (sem buraco)

func suppress_skills_temporarily(duration: float) -> void:
	_cast.suprimir(duration)

func lock_movement(duration: float, skill_id: String = "") -> void:
	# Ignora o timer (FSM cuida), mas mantém metadata
	set_meta("active_skill", skill_id)

## Teclas de habilidade de fruta que prendem o corpo enquanto apertadas. O F (voo, bicicleta,
## montaria) fica de fora: nele segurar é justamente andar.
const TECLAS_QUE_PRENDEM: Array[String] = ["Z", "X", "C", "V"]
var _teclas_seguradas := {}

## Alguma habilidade está com a tecla apertada? Preso no lugar (sem andar, pular nem
## esquivar; a gravidade segue). Skill do Builder com "Pode andar enquanto segura" é a
## exceção, e o menu aberto não conta (a tecla pode ter sido solta lá).
func habilidade_segurada_prende() -> bool:
	if _teclas_seguradas.is_empty() or combat_mode == "sword":
		return false
	for slot in _teclas_seguradas:
		var s := KitDoBuilder.skill(slot, current_fruit_id)
		if not s.is_empty() and bool(s.get("ativacao", {}).get("andar_segurando", false)):
			continue
		return true
	return false

## Alguma tecla segurada é de uma skill com "Paralisa segurando" (Nikyu Nikyu, 14/10/2026)?
## Aí o corpo fica parado onde está, sem gravidade — até no ar. Só no Modo História.
func habilidade_segurada_paralisa() -> bool:
	if _teclas_seguradas.is_empty() or perfil_de_frutas == null or combat_mode == "sword":
		return false
	for slot in _teclas_seguradas:
		var s := KitDoBuilder.skill(slot, current_fruit_id)
		if not s.is_empty() and bool(s.get("ativacao", {}).get("paralisar_segurando", false)) \
				and not bool(s.get("ativacao", {}).get("andar_segurando", false)):
			return true
	return false

func _notification(what: int) -> void:
	# Janela perdeu o foco com a tecla apertada: o soltar nunca chega — não deixar preso.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_teclas_seguradas.clear()

# CAST — a decisão mora em src/player/cast_controller.gd (passo 6c). Aqui ficam
# as cascas: a API pública que o input, a HUD e a rede já conhecem.
func begin_charge(slot: String) -> void:
	# TECLA DA HABILIDADE SEGURADA = JOGADOR PRESO NO LUGAR (pedido do dono, 14/10/2026).
	# O registro vale enquanto a tecla está apertada. Skill do BUILDER só prende se o golpe
	# SAIU (em recarga, sem energia ou com condição recusada, o corpo fica livre — pedido do
	# dono, 14/10/2026): o registro dela é feito depois do `comecar`, abaixo.
	var do_builder := KitDoBuilder.pelo_builder(current_fruit_id, slot)
	var pode_prender: bool = slot in TECLAS_QUE_PRENDEM and current_fruit_id != "" \
		and not (_arremesso != null and _arremesso.ativo())
	if pode_prender and not do_builder:
		_teclas_seguradas[slot] = true
	# `can_use_fruit` é a trava do Modo História: lá a fruta comida libera Z/X/C/V sem
	# abrir os modos 1/2/3, o T, o E e o Corpo de Ferro, que andam com `can_use_skills`.
	if not capacidades.can_use_skills and not capacidades.can_use_fruit:
		return
	if _arremesso.ativo():
		return
	if combat_mode == "sword":
		request_yoru_action(slot)
		return
	if not pode_conjurar():
		return
	_cast.comecar(slot)
	if pode_prender and do_builder and _cast.kit_em_curso(slot):
		_teclas_seguradas[slot] = true
	# O indicador acende DEPOIS: só quando a tecla armou mesmo a mira. Acender antes
	# mostrava alvo para um golpe que a recarga ou a energia iam recusar.
	if _cast.mirando() == slot:
		_mostrar_mira_de_fruta(slot)

func release_charge(slot: String) -> void:
	_teclas_seguradas.erase(slot)
	if combat_mode == "sword":
		return
	if _mira_fruta != null and _mira_fruta.mostrando() == slot:
		_mira_fruta.esconder()
	_cast.soltar(slot)


## Segurar a tecla MOSTRA onde o golpe vai cair; soltar apaga. Quem desenha é o
## `MiraDeFruta`, com a mesma conta do controlador. Só no Modo História (onde existe
## ficha) e só na autoridade: a mira de um corpo remoto seria a mira do outro jogador.
func _mostrar_mira_de_fruta(slot: String) -> void:
	if not _is_authority or perfil_de_frutas == null or not perfil_de_frutas.tem(slot):
		return
	if _mira_fruta == null:
		_mira_fruta = MIRA_DE_FRUTA.new()
		_mira_fruta.dono = self
		add_child(_mira_fruta)
	_mira_fruta.mostrar(slot)


func request_yoru_action(id: String) -> void:
	if _yoru_network:
		_yoru_network.request_action(id, RosaDosVentos.frente(_yaw))


func _cancel_yoru_action(reason: String) -> void:
	if _yoru_network:
		_yoru_network.cancel_action(reason)
	elif _yoru_combat:
		_yoru_combat.cancel(reason)



## Callback dos controladores Pacifista quando a janela mecanica acaba. O token
## torna a chamada idempotente e impede um efeito velho de limpar um cast novo.
func finalizar_skill_pacifista(slot: String, cast_token: int = 0) -> void:
	_cast.finalizar_pacifista(slot, cast_token)


## O controlador do Yasakani chama isto ao alcançar o fim máximo de 3,7 s.
## O caminho é o mesmo de soltar a tecla: publica o cancelamento e destrava.
func finalizar_skill_pika_c(cast_token: int = 0) -> void:
	_cast.finalizar_pika_c(cast_token)

# Compat: disparo imediato (sem segurar).
func cast_skill_slot(slot_key: String) -> void:
	if not pode_conjurar():
		return
	_cast.conjurar_direto(slot_key)

func _request_cast(slot: String) -> void:
	if not pode_conjurar():
		return
	_cast.pedir_cast(slot)

# ---- casting SERVIDOR-AUTORIDADE ----
# Cliente PEDE o cast -> servidor valida e é dono da hitbox -> a PRESENTATION
# (VFX/anim) roda em TODOS os clientes; o dano/knockback (DamageZone) só é ativo
# no servidor. Sem peer (SP puro/harness) roda tudo local, idêntico.
var _server_cast_next_ms: Dictionary = {}
var _server_last_cast_token: Dictionary = {}
## Intervalo entre golpes de fruta no servidor (07/10/2026): última tecla e quando outra
## pode sair. Folga de 80 % para a latência não recusar o golpe legítimo.
var _server_proximo_golpe_ms := 0
var _server_ultimo_golpe := ""


func _vetor_de_cast_finito(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


func _fonte_de_cast_valida(source_kind: String, source_id: String) -> bool:
	if source_kind == "style":
		return FightingStyles.STYLES.has(source_id)
	if source_kind == "fruit":
		if KitDoBuilder.e_do_builder(source_id):
			return KitDoBuilder.disponivel(source_id)
		return SkillSystem.get_fruit_skills().has(source_id)
	return false


## O servidor nao simula o input/cooldown da copia remota, então mantem um
## relógio monotônico pequeno por fonte+slot. Ele nao substitui o HUD; apenas
## impede RPC repetido de multiplicar hitboxes entre dois pacotes legítimos.
func _autorizar_cast_remoto(slot: String, aim: Vector3, origin: Vector3,
		cast_token: int, source_kind: String, source_id: String) -> bool:
	if has_meta("combate_mine_piece"):
		return false
	var kit := source_kind == "fruit" and KitDoBuilder.pelo_builder(source_id, slot)
	if not slot in ["Z", "X", "C", "V"] and not (slot == "F" and (kit or (source_kind == "fruit" and source_id == "tori_tori_phoenix"))):
		return false
	if not _vetor_de_cast_finito(aim) or not _vetor_de_cast_finito(origin):
		return false
	if aim.length_squared() < 0.0001 or global_position.distance_to(origin) > 4.5:
		return false
	if not _fonte_de_cast_valida(source_kind, source_id):
		return false

	var chave := "%s/%s/%s" % [source_kind, source_id, slot]
	if cast_token > 0:
		var anterior := int(_server_last_cast_token.get(chave, 0))
		if cast_token <= anterior:
			return false
		_server_last_cast_token[chave] = cast_token

	var agora := Time.get_ticks_msec()
	if agora < int(_server_cast_next_ms.get(chave, 0)):
		return false
	var recarga := RECARGA_ESTILO if source_kind == "style" else float(
		RECARGA_POR_SLOT.get(slot, 5.0))
	if source_kind == "fruit" and source_id in ["bomu_bomu", "suke_suke"]:
		recarga = 10.0
	if source_kind == "fruit" and source_id == "tori_tori_phoenix":
		recarga = SkillSystem.recarga_da_arena(slot, source_id) * 0.9
	if kit:
		# A recarga da skill; 90 % para a latência não recusar a repetição legítima.
		recarga = KitDoBuilder.recarga(slot, source_id) * 0.9
	# Intervalo entre golpes de fruta: só entre teclas DIFERENTES (as rajadas de um golpe
	# chegam como vários pedidos da mesma tecla e quem as limita é a recarga dela).
	if source_kind == "fruit" and slot != _server_ultimo_golpe and agora < _server_proximo_golpe_ms:
		return false
	if source_kind == "fruit":
		var intervalo := KitDoBuilder.intervalo_depois(slot, source_id) if kit else INTERVALO_ENTRE_GOLPES
		_server_ultimo_golpe = slot
		_server_proximo_golpe_ms = agora + int(intervalo * 0.8 * 1000.0)
	_server_cast_next_ms[chave] = agora + int(recarga * 1000.0)
	return true


@rpc("any_peer", "reliable")
func _net_cast(slot: String, aim: Vector3, origin: Vector3, charge: float = 0.0,
		cast_token: int = 0, source_kind: String = "", source_id: String = "") -> void:
	if multiplayer.is_server():
		var cid = multiplayer.get_remote_sender_id()
		if cid != 0 and cid != get_multiplayer_authority(): return
		if source_kind == "":
			source_kind = combat_mode
			source_id = estilo_atual() if source_kind == "style" else current_fruit_id
		if cid != 0 and source_id not in ["ope_ope", "bara_bara", "rocket"] and not _autorizar_cast_remoto(slot, aim, origin, cast_token,
				source_kind, source_id):
			return
		_do_server_cast(slot, aim, origin, charge, cast_token, source_kind, source_id)

# ======================= CORPO A CORPO (botão esquerdo) =======================

# ----------------- SOFT LOCK-ON E LUNGE -----------------
func find_best_melee_target(radius: float = 12.0) -> Node3D:
	var best_target: Node3D = null
	var highest_score: float = -9999.0
	
	var candidates = AlvosDeGolpe.todos(get_tree())
	for c in candidates:
		if c == self or not is_instance_valid(c):
			continue

		var dist = global_position.distance_to(c.global_position)
		if dist > radius:
			continue
			
		var dir_to_target = (c.global_position - global_position).normalized()
		# ⚠️ FRENTE INVERTIDA ATÉ 2026-08-25 — medido, não deduzido.
		#
		# Era `-Vector3.FORWARD.rotated(Vector3.UP, _yaw)`. `Vector3.FORWARD` já é
		# (0, 0, −1); negá-la dá (0, 0, +1), que é PARA TRÁS. Comparada com a
		# direção que a hitbox usa (`-Basis.from_euler(...).z`, em
		# `melee_controller.pedir`), o produto escalar é **−1,00 em todo yaw**.
		#
		# Consequência: o cone frontal selecionava alvos ATRÁS do jogador, e o
		# lunge o empurrava para longe do alvo — e para longe de onde a hitbox
		# ia nascer. Ver `docs/erros.md`.
		var forward = RosaDosVentos.frente(_yaw)   # definição canônica: RosaDosVentos
		
		var dot_prod = forward.dot(dir_to_target)
		
		# Cone frontal (dot > 0.0 significa à frente do jogador)
		if dot_prod > 0.0:
			var score = (dot_prod * 15.0) - dist
			if score > highest_score:
				highest_score = score
				best_target = c
				
	return best_target

func perform_melee_lunge(target: Node3D, lunge_force: float = 18.0) -> void:
	if not is_instance_valid(target):
		return
		
	# 1. Soft-Lock (Rodar para encarar)
	var dir = (target.global_position - global_position).normalized()
	dir.y = 0 
	if dir.length_squared() > 0.001:
		_yaw = atan2(-dir.x, -dir.z)
		if _char_model:
			_char_model.rotation.y = _yaw
			
	# 2. Lunge (Impulso Frontal Instantâneo)
	# Mesma correção de frente do `find_best_melee_target` — ver a nota lá.
	var forward = RosaDosVentos.frente(_yaw)   # definição canônica: RosaDosVentos
	# ⚠️ `lunge_force` NÃO FOI RECALIBRADO, e isso é medida, não omissão.
	# O §3.3 do plano pede um puxão de ~0,30 m por golpe. Isto aqui é um impulso
	# de UM QUADRO: `_etapa_locomocao` reescreve `velocity.x/z` no quadro
	# seguinte, então 18 m/s ÷ 60 = **0,30 m** — o número-alvo, já de pé. Trocar
	# 18 por 1,5 ("0,3 m/s") daria um puxão 60x menor.
	velocity = forward * lunge_force

# ----------------- COMBO BREAKER -----------------
func _request_combo_breaker() -> void:
	if _combo_breaker_cooldown > 0.0:
		print("Combo Breaker em cooldown (", snapped(_combo_breaker_cooldown, 0.1), "s restantes)")
		return
	
	# Só pode ativar se estiver tomando dano/hitstun (Stunned)
	var is_stunned = (_hitstop_timer > 0.0) or (_fsm and _fsm.state and _fsm.state.name == "Stunned")
	if is_stunned:
		print("💥 COMBO BREAKER ATIVADO!")
		_combo_breaker_cooldown = 45.0 # Cooldown longo punitivo
		
		# Destrava hitstop imediatamente
		if _hitstop_timer > 0.0:
			if _char_model:
				_char_model.position.x = 0.0
				_char_model.position.z = 0.0
			if _animator and _animator.animation_player:
				_animator.animation_player.speed_scale = 1.0
		_hitstop_timer = 0.0
		RecepcaoDeDano.limpar(self)
		
		# Limpa debuffs de stun
		if has_meta("is_frozen"): set_meta("is_frozen", false)
		if has_meta("in_vortex"): set_meta("in_vortex", false)
		if has_meta("in_black_hole"): set_meta("in_black_hole", false)
		if has_meta("in_kurouzu"): set_meta("in_kurouzu", false)
		if _fsm:
			_fsm.transition_to("Dashing") # Usa o estado de Dashing para fugir e ganhar invulnerabilidade
			
		# Feedback visual e knockback em área para afastar inimigos
		if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
			_do_server_combo_breaker(global_position)
		else:
			_net_combo_breaker.rpc_id(1, global_position)

@rpc("any_peer", "reliable")
func _net_combo_breaker(pos: Vector3) -> void:
	if multiplayer.is_server():
		_do_server_combo_breaker(pos)

func _do_server_combo_breaker(pos: Vector3) -> void:
	if multiplayer.has_multiplayer_peer():
		_net_play_combo_breaker.rpc(pos)
	else:
		_net_play_combo_breaker(pos)

@rpc("any_peer", "call_local", "reliable")
func _net_play_combo_breaker(pos: Vector3) -> void:
	# Efeito visual de Explosão de Ki/Burst
	var vfx := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	vfx.mesh = sphere
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.6, 1.0, 0.8) # Azul claro
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.2, 0.6, 1.0)
	m.emission_energy_multiplier = 3.0
	vfx.material_override = m
	vfx.position = pos
	var current_scene = get_tree().current_scene
	if current_scene: current_scene.add_child(vfx)
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(vfx, "scale", Vector3.ONE * 6.0, 0.3)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.set_parallel(false)
	tw.tween_callback(vfx.queue_free)
	
	if current_scene and AudioFX: AudioFX.hurt(current_scene, pos) # Som placeholder
	
	# Empurra inimigos próximos (só o servidor empurra)
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		var espaco = get_world_3d().direct_space_state
		var par = PhysicsShapeQueryParameters3D.new()
		var shape_cast = SphereShape3D.new()
		shape_cast.radius = 6.0
		par.shape = shape_cast
		par.transform = Transform3D(Basis(), pos)
		par.collide_with_areas = false
		par.collide_with_bodies = true
		par.collision_mask = 15
		if self is CollisionObject3D: par.exclude = [get_rid()]
		
		var hits = espaco.intersect_shape(par)
		for h in hits:
			var col = h.get("collider")
			if col != self and col is Node3D and col.has_method("take_damage"):
				var dir = (col.global_position - pos).normalized()
				dir.y = 0.5
				col.take_damage(0.0, pos, dir * 25.0, 0.5)
				var placar = get_tree().get_first_node_in_group("scoreboard")
				if placar and placar.has_method("register_hit"):
					placar.register_hit(col, self) # Zero dano, forte knockback

# --------------------------------------------------------

# Combo: soco DIREITO -> soco ESQUERDO -> CHUTE, encadeáveis dentro de
# Melee.JANELA (2 s). Segue o MESMO trajeto de rede das skills: o dono pede, o
# servidor cria a hitbox, todo mundo reproduz a animação.
func _request_melee() -> void:
	# Porta única do corpo a corpo: o buffer "attack" só é enchido aqui, e é dele
	# que saem o combo, o chute giratório e a queda esmagadora.
	if not capacidades.can_attack:
		return
	# Clique do Minecraft (V5): com as mãos livres ou no "luta", o pedido de golpe vira o BATER do clique (por aqui, sem mira de mouse).
	if clique_de_blocos != null and clique_de_blocos.assume_as_maos():
		clique_de_blocos.bater_no_que_esta_na_mira()
		return
	# Modo História: o clique é do combate direcional. Por esta porta (testes,
	# chamadas diretas) o golpe sai para a FRENTE; a direção pelo mouse chega pela
	# entrada própria do combate (Fase 2 do plano).
	if combate_direcional != null:
		combate_direcional.pedir_ataque(GolpeDirecional.Direcao.FRENTE)
		return
	if equipped_weapon == "sword":
		request_yoru_action("M1")
		return
	if _fsm and _fsm.state and _fsm.state.name == "Stunned":
		return # Não faz buffer se estiver atordoado
	_add_input_to_buffer("attack")

## Espaço + M1 — chute giratório curto inspirado em luta de rua. Não depende de
## alvo para começar: é uma variação intencional de mobilidade e acerta quem
## entrar na faixa frontal durante o giro.
## A que altura do chão o corpo está, em metros. 0,0 quando apoiado.
##
## ⚠️ POR RAIO, e não pela diferença até onde o pulo começou: o jogador pode ter
## saltado de uma plataforma alta e estar a 1 m do telhado de baixo, ou ter caído
## num buraco. O que importa para a leitura de quem olha é a distância até o chão
## que está SOB ele agora.
func altura_do_chao() -> float:
	if is_on_floor():
		return 0.0
	var espaco := get_world_3d().direct_space_state
	if espaco == null:
		return 0.0
	var de := global_position
	var par := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * ALCANCE_RAIO_CHAO)
	par.exclude = [get_rid()]
	var hit := espaco.intersect_ray(par)
	if hit.is_empty():
		return ALCANCE_RAIO_CHAO
	return de.distance_to(hit["position"])


## ASAS DE ANJO. Chamado pelo `MeleeController` ANTES da Aú: é mais específico
## que ela (exige raça, segundo pulo e alvo), e a regra da casa é a intenção mais
## específica vencer. Sem alvo por perto ele devolve `false` e o clique segue seu
## caminho normal — a Aú, ou o combo.
func tentar_asas_de_anjo(_yaw_ignorado: float = 0.0) -> bool:
	if _asas_ativas:
		return true
	if not AsasDeAnjo.disponivel(self, _asas_recarga):
		return false
	var alvo: Node3D = AsasDeAnjo.alvo_de(self)
	if alvo == null:
		return false

	_encerrar_mordida_mink()
	if _melee:
		_melee.cancelar_golpe()
	_asas_ativas = true
	_asas_t = 0.0
	_asas_acertou = false
	_asas_rumo = AsasDeAnjo.rumo(self, alvo)
	# O corpo olha para onde vai: a voadora sobe, desce ou atravessa, e a
	# silhueta precisa contar isso para quem está do outro lado.
	_yaw = atan2(-_asas_rumo.x, -_asas_rumo.z)
	set_meta("custom_pose", "asas_de_anjo")
	velocity = _asas_rumo * AsasDeAnjo.VELOCIDADE

	# A hitbox acompanha o corpo durante o voo inteiro: o golpe É o deslocamento,
	# então não há uma janela ativa separada do movimento.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		pedir_asas_de_anjo_no_servidor.rpc_id(1, _asas_rumo)
	else:
		_criar_hitbox_asas_de_anjo()
	return true


## O cliente pede; o servidor decide. Mesmo desenho dos ataques contextuais: o
## pedido leva só a DIREÇÃO, e o servidor confere o que consegue observar de
## forma autoritativa antes de instanciar a hitbox.
@rpc("any_peer", "call_remote", "reliable")
func pedir_asas_de_anjo_no_servidor(rumo: Vector3) -> void:
	if not multiplayer.is_server():
		return
	# ⚠️ O SERVIDOR REVALIDA. Um cliente adulterado poderia pedir a voadora no
	# chão, sem geppo, sem ser Skypean ou com o golpe em recarga — as quatro
	# condições são conferidas aqui de novo, com o estado que ESTE processo vê.
	if not AsasDeAnjo.disponivel(self, _asas_recarga):
		return
	if rumo.length_squared() < 0.5 or rumo.length_squared() > 1.5:
		return
	_asas_rumo = rumo.normalized()
	_criar_hitbox_asas_de_anjo()


func _criar_hitbox_asas_de_anjo() -> void:
	var zona := DamageZone.new()
	zona.name = "AsasDeAnjo"
	get_parent().add_child(zona)
	zona.global_position = global_position
	zona.override_kb_dir = _asas_rumo
	zona.hit_landed.connect(func(_alvo):
		# ⚠️ AQUI é que a recarga passa a ser devida. Enquanto não conectar, o
		# golpe sai de graça — pedido do dono.
		_asas_acertou = true
		hit_confirmed = true)
	zona.setup(AsasDeAnjo.DANO, AsasDeAnjo.KNOCKBACK, Vector3.ZERO,
		AsasDeAnjo.DURACAO, self, AsasDeAnjo.RAIO_HITBOX, null, AsasDeAnjo.HITSTUN)
	# A zona segue o corpo — quem a move é o `_tick_asas_de_anjo`, a cada quadro.
	# Sem isso ela ficaria parada no ponto de partida e a voadora atravessaria o
	# alvo sem tocar nele.
	_asas_zona = zona


func _tick_asas_de_anjo(delta: float) -> void:
	_asas_t += delta
	if is_instance_valid(_asas_zona):
		_asas_zona.global_position = global_position
	if _asas_t >= AsasDeAnjo.DURACAO:
		_encerrar_asas_de_anjo()
		return
	# mantém o rumo: a gravidade não deve curvar a voadora no meio do caminho
	velocity = _asas_rumo * AsasDeAnjo.VELOCIDADE


func _encerrar_asas_de_anjo() -> void:
	_asas_ativas = false
	_asas_t = 0.0
	if get_meta("custom_pose", "") == "asas_de_anjo":
		remove_meta("custom_pose")
	if is_instance_valid(_asas_zona):
		_asas_zona.queue_free()
	_asas_zona = null
	# ⚠️ A RECARGA SÓ AGORA, E SÓ SE ACERTOU. Errar custa o tempo do voo e a
	# posição — punição suficiente, segundo o dono — e o golpe fica disponível.
	if _asas_acertou:
		_asas_recarga = AsasDeAnjo.RECARGA
	_asas_acertou = false


func tentar_chute_giratorio(_yaw_ignorado: float = 0.0) -> bool:
	if equipped_weapon != "" or not Input.is_key_pressed(KEY_SPACE):
		return false
	if _spin_kick_active or _air_slam_active:
		return true
	if _spin_kick_cooldown > 0.0:
		return false
	# ⚠️ TETO DE ALTURA (pedido do dono, 2026-09-01): a Aú só começa até METADE
	# da altura de um pulo simples. Sem isso ela vira mobilidade aérea de graça —
	# o jogador sobe com geppo e abre o chute lá em cima, longe de qualquer
	# leitura de quem está no chão.
	#
	# A altura é DERIVADA, não digitada: v²/2g com os valores reais do pulo
	# (16 e 32) dá 4,00 m, e a metade é 2,00 m. Se o pulo mudar, o teto
	# acompanha sozinho.
	if altura_do_chao() > ALTURA_MAX_CHUTE_GIRATORIO:
		return false
	_encerrar_mordida_mink()
	if _melee:
		_melee.cancelar_golpe()
	_spin_kick_active = true
	_spin_kick_cooldown = RECARGA_CHUTE_GIRATORIO
	_spin_kick_angle = 0.0
	_spin_kick_yaw = _yaw
	if _char_model:
		_spin_kick_rest_position = _char_model.position
	set_meta("custom_pose", "spin_kick")
	var frente := RosaDosVentos.frente(_spin_kick_yaw)
	velocity.x = frente.x * 8.0
	velocity.z = frente.z * 8.0
	if is_on_floor():
		velocity.y = JUMP_VELOCITY * 0.62
	var impacto := get_tree().create_timer(0.16)
	impacto.timeout.connect(func():
		if not _spin_kick_active:
			return
		var mundo := get_tree().current_scene
		if mundo:
			SpinKickFXClass.disparar(mundo, global_position, RosaDosVentos.frente(_spin_kick_yaw), self))
	var fim := get_tree().create_timer(0.42)
	fim.timeout.connect(_encerrar_chute_giratorio)
	return true

func _encerrar_chute_giratorio() -> void:
	_spin_kick_active = false
	_spin_kick_angle = 0.0
	if _char_model:
		_char_model.rotation.z = 0.0
		_char_model.position = _spin_kick_rest_position
	if String(get_meta("custom_pose", "")) == "spin_kick":
		remove_meta("custom_pose")

## Queda esmagadora — M1 no ar com adversário abaixo. Esta consulta é separada
## do cone frontal normal porque o alvo pode estar diretamente sob os pés.
func tentar_ataque_aereo(_yaw_ignorado: float = 0.0) -> bool:
	if equipped_weapon != "" or is_on_floor() or _air_slam_active or _air_slam_cooldown > 0.0:
		return false
	# O mergulho só existe acima da altura que já é forte o bastante para rachar
	# o solo no pouso normal. A constante é a mesma do FallImpactController —
	# não há um segundo número de "queda alta" para os dois efeitos divergirem.
	if _altura_para_impacto_aereo() < FallImpactController.ALTURA_MINIMA:
		return false
	var alvo := _alvo_abaixo_para_queda()
	if alvo == null:
		return false
	# O mergulho ganha de qualquer outro especial: não pode sobrar agarrão,
	# pose ou timer da mordida enquanto o corpo está caindo.
	_encerrar_mordida_mink()
	if _melee:
		_melee.cancelar_golpe()
	_air_slam_active = true
	_air_slam_cooldown = RECARGA_QUEDA_ESMAGADORA
	# Se acabou de sair do ápice, ainda pode estar quase em 0: dá o primeiro
	# impulso descendente mínimo e, fora isso, triplica o vetor de queda real.
	velocity.y = -maxf(absf(velocity.y) * 3.0, 3.0)
	set_meta("custom_pose", "air_slam_dive")
	return true

func _altura_para_impacto_aereo() -> float:
	if get_world_3d() == null:
		return 0.0
	var inicio := global_position + Vector3.UP * 0.15
	var consulta := PhysicsRayQueryParameters3D.create(inicio, inicio + Vector3.DOWN * 40.0, 15, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(consulta)
	if hit.is_empty():
		return 0.0
	return inicio.y - (hit["position"] as Vector3).y

func _alvo_abaixo_para_queda() -> Node3D:
	var melhor: Node3D = null
	var melhor_dist := INF
	for candidato in AlvosDeGolpe.todos(get_tree()):
		if candidato == self or not is_instance_valid(candidato) or not candidato is Node3D:
			continue
		var alvo := candidato as Node3D
		var delta := alvo.global_position - global_position
		# Só vale queda de verdade: o inimigo está abaixo e razoavelmente sob o
		# jogador, não um oponente distante que aconteça a estar mais baixo.
		if delta.y > -0.45 or Vector2(delta.x, delta.z).length() > 5.6:
			continue
		var dist := delta.length_squared()
		if dist < melhor_dist:
			melhor = alvo
			melhor_dist = dist
	return melhor

func _finalizar_ataque_aereo() -> void:
	_air_slam_active = false
	if String(get_meta("custom_pose", "")) == "air_slam_dive":
		remove_meta("custom_pose")
	var mundo := get_tree().current_scene
	if mundo:
		AirSlamFXClass.impactar(mundo, global_position + Vector3(0, -0.72, 0), self)


## Estilo Mink — galope, mordida e chute. Só nasce em sprint e com uma raça
## Mink montada no modelo; a escolha evita transformar qualquer M1 em especial.
func tentar_combo_mink(yaw: float) -> bool:
	if equipped_weapon != "" or not _is_sprinting() or _char_model == null:
		return false
	var raca := String(_char_model.get_meta("raca_id", ""))
	if not raca in ["mink_coelho", "mink_lobo", "mink_lobo_neve"]:
		return false
	if is_instance_valid(_mink_bite_target) and _mink_hold_timer > 0.0:
		_executar_chute_mink()
		return true
	if _mink_bite_dash:
		return true
	# Durante a recarga o clique segue para o M1 móvel normal. Assim o jogador
	# não fica sem atacar só porque a variação de corrida está indisponível.
	if _mink_bite_cooldown > 0.0:
		return false
	var alvo := find_best_melee_target(11.0)
	if alvo == null:
		return false
	var plano := alvo.global_position - global_position
	plano.y = 0.0
	if plano.length_squared() < 0.01:
		return false
	_mink_bite_dir = plano.normalized()
	_yaw = atan2(-_mink_bite_dir.x, -_mink_bite_dir.z)
	_mink_bite_target = alvo
	_mink_bite_dash = true
	_mink_bite_timer = 0.46
	set_meta("custom_pose", "mink_bite_dash")
	return true


func _process_mink_bite(delta: float) -> void:
	_mink_bite_timer -= delta
	if not is_instance_valid(_mink_bite_target) or _mink_bite_timer <= 0.0:
		_encerrar_mordida_mink()
		return
	var dist := global_position.distance_to(_mink_bite_target.global_position)
	if dist > 1.75:
		return
	_mink_bite_dash = false
	_mink_hold_timer = 1.15
	_mink_bite_cooldown = RECARGA_MORDIDA_MINK
	_mink_bite_target.set_meta("is_frozen", true)
	StatusFX.aplicar(_mink_bite_target, StatusFX.CONGELADO, _mink_hold_timer)
	# A mordida confirma o agarrão; o chute seguinte é o golpe de arremesso.
	# Pelo CombatResolver com o dono como atacante de corpo a corpo: para quem
	# reage a M1 (o Boss) a mordida e o chute contam como golpes seguidos.
	CombatResolver.aplicar(_mink_bite_target, 54.0, 0, 0.0, _mink_bite_target.global_position, Vector3.ZERO, 0.28, 0.0, false, self)
	set_meta("custom_pose", "mink_bite_hold")


func _process_mink_hold(delta: float) -> void:
	if not is_instance_valid(_mink_bite_target):
		_encerrar_mordida_mink()
		return
	_mink_hold_timer -= delta
	_mink_bite_target.global_position = global_position + _mink_bite_dir * 1.05 + Vector3.UP * 0.35
	if _mink_hold_timer <= 0.0:
		_encerrar_mordida_mink()


func _executar_chute_mink() -> void:
	if not is_instance_valid(_mink_bite_target):
		_encerrar_mordida_mink()
		return
	_mink_bite_target.set_meta("is_frozen", false)
	var impulso := (_mink_bite_dir + Vector3.UP * 0.32).normalized() * 48.0
	CombatResolver.aplicar(_mink_bite_target, 116.0, 0, 0.0, _mink_bite_target.global_position, impulso, 0.72, 0.0, false, self)
	set_meta("custom_pose", "mink_kick")
	var limpar := get_tree().create_timer(0.34)
	limpar.timeout.connect(_encerrar_mordida_mink)


func _encerrar_mordida_mink() -> void:
	_mink_bite_dash = false
	_mink_bite_timer = 0.0
	_mink_hold_timer = 0.0
	if is_instance_valid(_mink_bite_target):
		_mink_bite_target.set_meta("is_frozen", false)
	_mink_bite_target = null
	if String(get_meta("custom_pose", "")).begins_with("mink_"):
		remove_meta("custom_pose")

## W/A/S/D — ataque contextual. O MeleeController é o dono do relógio; o
## Player só fixa direção, aplica root motion, apresenta e atravessa a rede.
func iniciar_ataque_contextual(id: String, yaw: float) -> bool:
	if not ContextualMeleeData.e_id_valido(id) or equipped_weapon != "":
		return false
	# O chute aéreo e o de parede existem justamente fora do chão; as variações
	# de solo continuam exigindo os pés apoiados. Ver `ContextualMelee.exige_chao`.
	if ContextualMeleeData.exige_chao(id) and not is_on_floor():
		return false
	_contextual_attack_seq += 1
	_apresentar_ataque_contextual(id, yaw, _contextual_attack_seq)
	var escala := scale.y
	var origem := global_position + Vector3.UP * escala
	pedir_ataque_contextual_no_servidor(_contextual_attack_seq, id, origem,
		RosaDosVentos.frente(yaw))
	return true

func sequencia_contextual_atual() -> int:
	return _contextual_attack_seq

func _processar_movimento_contextual() -> void:
	if _melee == null or not _melee.contextual_ativo():
		return
	var id := _melee.contextual_id()
	var frente := RosaDosVentos.frente(_contextual_attack_yaw)
	var rumo := ContextualMeleeData.direcao_de_deslocamento(id, frente)
	var velocidade := ContextualMeleeData.velocidade_de_deslocamento(id, _melee.tempo_na_fase())
	velocity.x = rumo.x * velocidade
	velocity.z = rumo.z * velocidade

func _limpar_vfx_contextual(id: String) -> void:
	# Uma nova ação pode reutilizar o mesmo ID antes de o fade da anterior acabar.
	# Limpar pelo prefixo evita uma pilha de telegráficos e garante que uma
	# rejeição local desapareça imediatamente, não após o autofree visual.
	var prefixo := "ContextualMeleeFX_" + id
	for filho in get_children():
		if str(filho.name).begins_with(prefixo):
			filho.queue_free()

func _apresentar_ataque_contextual(id: String, yaw: float, sequencia: int) -> void:
	# O host prevê antes de o RPC voltar. A deduplicação é por sequência, não por
	# ID: duas cotoveladas consecutivas são ações diferentes; o eco da primeira
	# não pode apagar nem recriar a segunda.
	if sequencia == _contextual_presented_seq:
		return
	if not _contextual_attack_id.is_empty() and _contextual_attack_id != id:
		_limpar_vfx_contextual(_contextual_attack_id)
	elif not _contextual_attack_id.is_empty():
		_limpar_vfx_contextual(id)
	_contextual_attack_id = id
	_contextual_attack_yaw = yaw
	_contextual_presented_seq = sequencia
	_contextual_presentation_token += 1
	var token := _contextual_presentation_token
	var ficha := ContextualMeleeData.especificacao(id)
	set_meta("custom_pose", str(ficha.get("pose", "")))
	if _char_model:
		_char_model.rotation.y = yaw
	ContextualMeleeFXClass.apresentar(self, id, yaw)
	# Este timer existe apenas para cópias remotas, que não rodam o
	# MeleeController da autoridade. O relógio de gameplay continua único e vive
	# no controlador; os 0,12 s cobrem a recuperação extra de whiff visual.
	var fim := get_tree().create_timer(ContextualMeleeData.duracao(id) + 0.12)
	fim.timeout.connect(func():
		if _contextual_presentation_token == token and _contextual_presented_seq == sequencia:
			encerrar_ataque_contextual(id))

func encerrar_ataque_contextual(id: String) -> void:
	if id != _contextual_attack_id:
		return
	var pose := str(ContextualMeleeData.especificacao(id).get("pose", ""))
	_contextual_attack_id = ""
	if String(get_meta("custom_pose", "")) == pose:
		remove_meta("custom_pose")

func cancelar_ataque_contextual(id: String, sequencia: int, avisar_servidor: bool = true) -> void:
	# Esta entrada é chamada pelo MeleeController em dash-cancel, troca por uma
	# ação de prioridade maior e limpeza de estado. O mesmo seq jamais cancela um
	# ataque iniciado depois.
	if sequencia != _contextual_attack_seq or id != _contextual_attack_id:
		return
	_contextual_presentation_token += 1
	_limpar_vfx_contextual(id)
	encerrar_ataque_contextual(id)
	if avisar_servidor:
		pedir_cancelamento_contextual_no_servidor(sequencia)

func _cancelar_contextual_local(sequencia: int) -> void:
	if sequencia != _contextual_attack_seq:
		return
	if _melee and _melee.has_method("cancelar_contextual_por_seq"):
		_melee.cancelar_contextual_por_seq(sequencia)
	elif not _contextual_attack_id.is_empty():
		cancelar_ataque_contextual(_contextual_attack_id, sequencia, false)

func pedir_ataque_contextual_no_servidor(sequencia: int, id: String, origem: Vector3, fwd: Vector3) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_contextual_melee(sequencia, id, origem, fwd)
	else:
		_net_contextual_melee.rpc_id(1, sequencia, id, origem, fwd)

func pedir_cancelamento_contextual_no_servidor(sequencia: int) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_cancelar_contextual_servidor(sequencia, false)
	else:
		_net_cancel_contextual_melee.rpc_id(1, sequencia)

## Clipe de animação do mod (`MinepieceModAnimationMessage`): o servidor roda o mod e manda o pacote aos clientes, que o tocam
## no corpo (o meta `pose_do_mod` não é replicado). Só o servidor (peer 1) pode mandar.
@rpc("any_peer", "call_remote", "reliable")
func _net_animacao_do_mod(clipe: String, sobrescrever: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	AnimacaoDoMod.no_de(self).tocar(clipe, sobrescrever)

@rpc("any_peer", "call_remote", "reliable")
func _net_melee(passo: int, origem: Vector3, fwd: Vector3) -> void:
	if multiplayer.is_server():
		var cid = multiplayer.get_remote_sender_id()
		if cid != 0 and cid != get_multiplayer_authority(): return
		_do_server_melee(passo, origem, fwd)

@rpc("any_peer", "call_remote", "reliable")
func _net_contextual_melee(sequencia: int, id: String, origem: Vector3, fwd: Vector3) -> void:
	if multiplayer.is_server():
		var cid := multiplayer.get_remote_sender_id()
		if cid != 0 and cid != get_multiplayer_authority():
			return
		_do_server_contextual_melee(sequencia, id, origem, fwd)

@rpc("any_peer", "call_remote", "reliable")
func _net_cancel_contextual_melee(sequencia: int) -> void:
	if not multiplayer.is_server():
		return
	var cid := multiplayer.get_remote_sender_id()
	if cid != 0 and cid != get_multiplayer_authority():
		return
	_cancelar_contextual_servidor(sequencia, false)

func _esta_no_chao_contextual_servidor() -> bool:
	# Em cópias remotas o servidor não roda move_and_slide(), logo is_on_floor()
	# não descreve aquele corpo. A flag publicada pelo dono é só o primeiro
	# indício; o raycast do servidor confirma que existe solo próximo à posição
	# replicada antes de aceitar uma variação exclusiva do chão.
	if _is_authority:
		return is_on_floor()
	if not net_on_floor or get_world_3d() == null:
		return false
	var inicio := global_position + Vector3.UP * 0.35
	var fim := inicio + Vector3.DOWN * 2.10
	var consulta := PhysicsRayQueryParameters3D.create(inicio, fim, 15, [get_rid()])
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true
	return not get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()

func _rejeitar_contextual_servidor(sequencia: int) -> void:
	var dono := get_multiplayer_authority()
	if multiplayer.has_multiplayer_peer() and dono != multiplayer.get_unique_id():
		_net_contextual_rejected.rpc_id(dono, sequencia)
	else:
		_net_contextual_rejected(sequencia)

func _cancelar_contextual_servidor(sequencia: int = -1, rejeitado: bool = false) -> void:
	if _server_contextual_active_seq < 0:
		return
	if sequencia >= 0 and sequencia != _server_contextual_active_seq:
		return
	var seq_cancelada := _server_contextual_active_seq
	_server_contextual_token += 1
	_server_contextual_active_seq = -1
	_server_contextual_deadline_ms = 0
	var dono := get_multiplayer_authority()
	if multiplayer.has_multiplayer_peer() and dono != multiplayer.get_unique_id():
		if rejeitado:
			_net_contextual_rejected.rpc_id(dono, seq_cancelada)
		else:
			_net_contextual_cancelled.rpc_id(dono, seq_cancelada)
	elif rejeitado:
		_net_contextual_rejected(seq_cancelada)
	else:
		_net_contextual_cancelled(seq_cancelada)

func _contextual_servidor_pode_gerar_zona(sequencia: int, token: int) -> bool:
	return sequencia == _server_contextual_active_seq \
		and token == _server_contextual_token \
		and Time.get_ticks_msec() <= _server_contextual_deadline_ms

func _confirmar_acerto_contextual_servidor(sequencia: int) -> void:
	if sequencia != _server_contextual_active_seq:
		return
	var dono := get_multiplayer_authority()
	if multiplayer.has_multiplayer_peer() and dono != multiplayer.get_unique_id():
		_net_contextual_hit_confirmed.rpc_id(dono, sequencia)
	else:
		_net_contextual_hit_confirmed(sequencia)

func _do_server_contextual_melee(sequencia: int, id: String, origem: Vector3, fwd: Vector3) -> void:
	# O servidor não recebe teclas do cliente. Ele valida tudo que pode observar
	# sem inventar uma segunda simulação de input: enum, arma, chão, direção,
	# origem e cadência. A DamageZone abaixo continua sendo a única fonte de dano.
	# `last_seq` é marcada antes das demais recusas para que um pacote repetido
	# não possa ser testado indefinidamente até achar uma janela válida.
	if sequencia <= _server_contextual_last_seq:
		return
	_server_contextual_last_seq = sequencia
	if sequencia < 0 or not ContextualMeleeData.e_id_valido(id) or equipped_weapon != "":
		_rejeitar_contextual_servidor(sequencia)
		return
	# A exigência de chão é POR GOLPE desde a Fase 4: as variações aéreas seriam
	# rejeitadas aqui em partida com rede, e passariam no singleplayer — onde o
	# cliente é o servidor. O tipo de bug que só aparece com duas máquinas.
	if ContextualMeleeData.exige_chao(id) and not _esta_no_chao_contextual_servidor():
		_rejeitar_contextual_servidor(sequencia)
		return
	if fwd.length_squared() < 0.25 or absf(fwd.y) > 0.15:
		_rejeitar_contextual_servidor(sequencia)
		return
	if global_position.distance_to(origem) > 3.0 or absf(origem.y - global_position.y) > 2.5:
		_rejeitar_contextual_servidor(sequencia)
		return
	var agora := Time.get_ticks_msec()
	if agora < _server_contextual_next_ms:
		_rejeitar_contextual_servidor(sequencia)
		return
	_server_contextual_next_ms = agora + int(ContextualMeleeData.duracao(id) * 1000.0)
	_server_contextual_active_seq = sequencia
	_server_contextual_token += 1
	_server_contextual_deadline_ms = _server_contextual_next_ms
	var frente := Vector3(fwd.x, 0.0, fwd.z).normalized()
	ContextualMeleeData.golpear(get_tree().current_scene, self, id, origem, frente,
		sequencia, _server_contextual_token)
	if multiplayer.has_multiplayer_peer():
		_net_play_contextual_melee.rpc(sequencia, id, frente)
	else:
		_net_play_contextual_melee(sequencia, id, frente)

@rpc("any_peer", "call_local", "reliable")
func _net_play_contextual_melee(sequencia: int, id: String, fwd: Vector3) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	if not ContextualMeleeData.e_id_valido(id):
		return
	var plano := Vector3(fwd.x, 0.0, fwd.z)
	if plano.length_squared() < 0.001:
		return
	_apresentar_ataque_contextual(id, atan2(-plano.x, -plano.z), sequencia)

@rpc("any_peer", "call_remote", "reliable")
func _net_contextual_hit_confirmed(sequencia: int) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	if _melee and _melee.has_method("confirmar_contextual"):
		_melee.confirmar_contextual(sequencia)

@rpc("any_peer", "call_remote", "reliable")
func _net_contextual_rejected(sequencia: int) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	_cancelar_contextual_local(sequencia)

@rpc("any_peer", "call_remote", "reliable")
func _net_contextual_cancelled(sequencia: int) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	_cancelar_contextual_local(sequencia)

# SERVIDOR: cria a hitbox (a DamageZone só machuca no servidor) e manda todos
# reproduzirem a animação do golpe.
func _do_server_melee(passo: int, origem: Vector3, fwd: Vector3) -> void:
	# O RPC legado nunca arma a Yoru, nem contorna a sequência autoritativa.
	if equipped_weapon == "sword" or combat_mode == "sword":
		return
	Melee.golpear(get_tree().current_scene, self, passo, origem, fwd)
	if multiplayer.has_multiplayer_peer():
		_net_play_melee.rpc(passo)
	else:
		_net_play_melee(passo)

@rpc("any_peer", "call_local", "reliable")
func _net_play_melee(passo: int) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender = multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1: return
	if not _proc_anim:
		return
	
	if equipped_weapon == "sword":
		# Para espada, tocar animação procedural no torso e braços para liberar pernas
		var g := Melee.passo(passo, equipped_weapon)
		var duracao = Melee.duracao_tocada(passo, equipped_weapon)
		var speed = 1.0 / maxf(duracao, 0.1) # Normalizado para 1.0s = fim da duração
		# ⚠️ O TIPO DO CORTE VEM DA TABELA, NÃO DO ÍNDICE DO PASSO (2026-09-06).
		# Era `play_procedural_slash(passo, ...)`, e funcionava por coincidência:
		# o combo tinha três passos e o `WeaponPoses` tem três tipos, então
		# 0/1/2 batiam. Com o combo virando um PAR (horizontal, vertical) o
		# passo 1 pediria o tipo 1 — que é o segundo corte HORIZONTAL — e o
		# vertical nunca sairia. O campo `slash_type` desfaz o acoplamento.
		# As fronteiras do golpe saem da MESMA tabela que arma a hitbox, para a
		# lâmina passar exatamente na janela ativa. Ver `Melee.fracao_do_golpe`.
		var fases := Melee.fracao_do_golpe(passo, equipped_weapon)
		_proc_anim.play_procedural_slash(
			Melee.slash_type(passo, equipped_weapon), speed, fases.x, fases.y)
	else:
		# Para normal, tocar clipe (.res) retargetado
		var clipe := Melee.clipe(passo, equipped_weapon)
		if clipe:
			var g := Melee.passo(passo, equipped_weapon)
			# `inicio` e `fim` DERIVADOS do frame data (2026-08-25): a janela é
			# posicionada para o pico medido do membro cair no fim do startup e
			# fechada na trava. Para a espada, que não foi convertida, os dois
			# devolvem o comportamento antigo (campo `inicio` da tabela, clipe
			# até o fim).
			_proc_anim.play_baked(clipe, float(g["vel"]),
				Melee.inicio(passo, equipped_weapon),
				String(g.get("melee_guarda", "")),
				Melee.fim_da_janela(passo, equipped_weapon))

# --- GURA GURA Z: INVESTIDA FÍSICA ---
## Direção do CORPO até o ponto que o retículo marca. A mira (`mira_do_cast`) sai da
## linha da câmera de OMBRO: um golpe que sai do corpo com ela anda paralelo ao
## retículo e passa ~1,5 m ao lado do alvo (investidas da Gura e da Bomu, 05/10/2026).
func rumo_ao_ponto_mirado(aim: Vector3, alcance := 40.0) -> Vector3:
	if not is_inside_tree() or _cam == null:
		return aim
	var origem: Vector3 = mira_do_cast()["origem"]
	var ponto := AlvosDeGolpe.ponto_mirado(get_world_3d(), origem, aim, alcance, [get_rid()])
	var d := ponto - (global_position + Vector3.UP * 1.0)
	return d.normalized() if d.length() > 0.5 else aim


func start_gura_rush(aim_dir: Vector3) -> void:
	if _gura_rush_active or _skill_cooldowns.get("Z", 0.0) > 0.0: return
	aim_dir = rumo_ao_ponto_mirado(aim_dir)
	_gura_rush_active = true
	_gura_rush_timer = 0.6 # Tempo máximo correndo
	_gura_grab_timer = 0.0
	_gura_rush_target = null
	var flat = Vector3(aim_dir.x, 0, aim_dir.z)
	_gura_rush_dir = flat.normalized() if flat.length() > 0.1 else -global_transform.basis.z
	trigger_skill_cooldown("Z")
	gastar_energia(custo_de_energia_do_cast("Z"))
	congelar_para_cast()
	set_meta("custom_pose", "gura_rush")

func _process_gura_rush(delta: float) -> void:
	if _gura_grab_timer > 0.0:
		velocity = Vector3.ZERO # Para imediatamente
		_gura_grab_timer -= delta
		if _gura_grab_timer <= 0.0:
			_gura_rush_active = false
			remove_meta("custom_pose")
			if is_instance_valid(_gura_rush_target):
				_gura_rush_target.set_meta("is_frozen", false)
				_gura_rush_target = null
		elif is_instance_valid(_gura_rush_target):
			# Sincroniza e prende a posição do inimigo ao jogador de forma absoluta
			_gura_rush_target.global_position = global_position + _gura_rush_dir * 1.5 + Vector3.UP * 0.5
		return

	_gura_rush_timer -= delta
	if _gura_rush_timer <= 0.0:
		_gura_rush_active = false
		remove_meta("custom_pose")
		return
		
	# Detecção da hitbox de inimigo (Area3D ou Body) usando Shape Cast
	var mundo = get_world_3d()
	var par = PhysicsShapeQueryParameters3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.2
	par.shape = shape
	# No CENTRO do corpo, não 1 m acima: com a Gura em escala 2 a esfera ia de 1,4 a
	# 3,8 m de altura e passava por cima de um bicho baixo — a investida encostava na
	# vaca e o soco nunca saía (medido em 05/10/2026).
	par.transform = Transform3D(Basis(), global_position + _gura_rush_dir * 1.5)
	par.collide_with_areas = true
	par.collide_with_bodies = true
	par.collision_mask = 15
	if self is CollisionObject3D: par.exclude = [get_rid()]
	
	var hits = mundo.direct_space_state.intersect_shape(par)
	for h in hits:
		var col = h.get("collider")
		if col != self and col is Node3D and col.has_method("take_damage") and not (col.has_meta("is_frozen") and col.get_meta("is_frozen")):
			_gura_rush_target = col
			_gura_rush_target.set_meta("is_frozen", true)
			StatusFX.aplicar(_gura_rush_target, StatusFX.CONGELADO, 1.0) # Desativa controle do alvo
			_gura_grab_timer = 0.5 # Tempo para sincronizar a animação do soco
			# Dispara o golpe visual (RPC) com charge 1.0 (golpe rápido e fatal)
			pedir_cast_no_servidor("Z", _gura_rush_dir, global_position, 1.0)
			break

# --- BOMU BOMU Z: corrida, agarrão e detonação ---
func start_bomu_rush(aim_dir: Vector3, _charge: float = 0.5) -> void:
	if _bomu_rush_active:
		return
	aim_dir = rumo_ao_ponto_mirado(aim_dir)
	_bomu_rush_active = true
	_bomu_rush_timer = 0.72
	_bomu_grab_timer = 0.0
	var flat := Vector3(aim_dir.x, 0.0, aim_dir.z)
	_bomu_rush_dir = flat.normalized() if flat.length_squared() > 0.01 else -global_transform.basis.z
	set_meta("custom_pose", "bomu_z_charge")
	_bomu_hand_charge = BomuFX.criar_carga_na_mao(self)

func _process_bomu_rush(delta: float) -> void:
	if _bomu_grab_timer > 0.0:
		velocity = Vector3.ZERO
		_bomu_grab_timer -= delta
		if is_instance_valid(_bomu_rush_target):
			_bomu_rush_target.global_position = global_position + _bomu_rush_dir * 1.28 + Vector3.UP * 0.35
		if _bomu_grab_timer <= 0.0:
			pedir_cast_no_servidor("Z", _bomu_rush_dir, global_position, 0.5)
			_encerrar_bomu_rush()
		return
	_bomu_rush_timer -= delta
	if _bomu_rush_timer <= 0.0:
		_encerrar_bomu_rush()
		return
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.15
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position + Vector3.UP + _bomu_rush_dir * 1.35)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 15
	query.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(query):
		var alvo := hit.get("collider") as Node3D
		if alvo != self and is_instance_valid(alvo) and alvo.has_method("take_damage") and not alvo.get_meta("is_frozen", false):
			_bomu_rush_target = alvo
			_bomu_rush_target.set_meta("is_frozen", true)
			StatusFX.aplicar(_bomu_rush_target, StatusFX.CONGELADO, 0.42)
			_bomu_grab_timer = 0.20
			set_meta("custom_pose", "bomu_z_strike")
			break

func _encerrar_bomu_rush() -> void:
	_bomu_rush_active = false
	_bomu_rush_timer = 0.0
	_bomu_grab_timer = 0.0
	if is_instance_valid(_bomu_rush_target):
		_bomu_rush_target.set_meta("is_frozen", false)
		_bomu_rush_target = null
	if is_instance_valid(_bomu_hand_charge):
		_bomu_hand_charge.queue_free()
	_bomu_hand_charge = null
	if get_meta("custom_pose", "").begins_with("bomu_"):
		remove_meta("custom_pose")

# SERVIDOR = autoridade: (validaria cooldown/estado) e manda TODOS reproduzirem.
## Transação de combate da Ope: somente servidor, custos após toda validação.
func _autorizar_ope(slot: String, aim: Vector3, origin: Vector3, token: int) -> bool:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return false
	var reason := OPE.validation_reason(self, slot, aim)
	if not origin.is_finite() or global_position.distance_to(origin) > 4.5:
		reason = "Origem da técnica inválida."
	var key := "fruit/ope_ope/" + slot
	var now := Time.get_ticks_msec()
	if reason == "" and (now < int(_server_cast_next_ms.get(key, 0)) \
			or float(_fruit_cooldowns.get(slot, 0.0)) > 0.0):
		reason = "Técnica em recarga."
	if reason == "" and token > 0 and token <= int(_server_last_cast_token.get(key, 0)):
		reason = "Pedido já processado."
	if reason == "" and energy < custo_de_energia_do_cast(slot):
		reason = "Energia insuficiente."
	if reason != "":
		if multiplayer.has_multiplayer_peer() and not _is_authority:
			_net_ope_rejected.rpc_id(get_multiplayer_authority(), token, reason)
		else:
			_net_ope_rejected(token, reason)
		return false
	_server_cast_next_ms[key] = now + int(SkillSystem.get_slot_cooldown(slot, "ope_ope") * 1000.0)
	_server_last_cast_token[key] = token
	gastar_energia(custo_de_energia_do_cast(slot))
	# Cópias remotas usam relógio de servidor; a autoridade usa o HUD normal.
	if _is_authority:
		trigger_skill_cooldown(slot)
	return true


@rpc("any_peer", "reliable")
func _net_ope_rejected(token: int, reason: String) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	if token == int(get_meta("ope_pending_token", 0)):
		set_meta("ope_pending_until", 0)
	OPE.feedback(self, reason)


## O servidor publica os dois destinos juntos. Cada dono move seu próprio corpo,
## evitando que a replicação desfaça a troca no quadro seguinte.
func ope_relocate(from: Vector3, to: Vector3, victim: NodePath,
		victim_to: Vector3, swap: bool) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if multiplayer.has_multiplayer_peer():
		_net_ope_relocate.rpc(from, to, victim, victim_to, swap)
	else:
		_net_ope_relocate(from, to, victim, victim_to, swap)


@rpc("any_peer", "call_local", "reliable")
func _net_ope_relocate(from: Vector3, to: Vector3, victim: NodePath,
		victim_to: Vector3, swap: bool) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	global_position = to
	velocity = Vector3.ZERO
	net_velocity = Vector3.ZERO
	reset_physics_interpolation()
	if not victim.is_empty():
		var target := get_node_or_null(victim) as Node3D
		if is_instance_valid(target):
			target.global_position = victim_to
			if target is CharacterBody3D:
				target.velocity = Vector3.ZERO
			if target is Player:
				target.net_velocity = Vector3.ZERO
			target.reset_physics_interpolation()
	if swap:
		OPE_VFX.shambles(_get_skills_container(), from, to)


## Eventos autoritativos mantêm colisão/agulha e apresentação no mesmo instante.
func ope_event(token: int, event: String, index: int = -1,
		at: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.FORWARD) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if multiplayer.has_multiplayer_peer():
		_net_ope_event.rpc(token, event, index, at, direction)
	else:
		_net_ope_event(token, event, index, at, direction)


@rpc("any_peer", "call_local", "reliable")
func _net_ope_event(token: int, event: String, index: int,
		at: Vector3, direction: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	if not is_instance_valid(_spawned_skills_container):
		return
	for effect in _spawned_skills_container.get_children():
		if effect.get_script() == OPE and effect.cast_token == token:
			effect.present_event(event, index, at, direction)
			return


# O servidor publica o fim do cão: clientes não ficam imunes até o timeout
# quando o contato autoritativo já explodiu a transformação.
@rpc("any_peer", "call_remote", "reliable")
func _net_magu_fim(token: int, posicao: Vector3, pedra: bool) -> void:
	if multiplayer.get_remote_sender_id() != NetworkConfig.SERVER_ID:
		return
	if not is_instance_valid(_spawned_skills_container):
		return
	for efeito in _spawned_skills_container.get_children():
		if efeito.has_method("receber_fim") and int(efeito.get("token")) == token:
			efeito.receber_fim(posicao, pedra)


func _do_server_cast(slot: String, aim: Vector3, origin: Vector3, charge: float = 0.0,
		cast_token: int = 0, source_kind: String = "", source_id: String = "") -> void:
	if source_kind == "":
		source_kind = combat_mode
		source_id = estilo_atual() if source_kind == "style" else current_fruit_id
	if not _fonte_de_cast_valida(source_kind, source_id):
		return
	if (has_meta("magu_acao") and is_instance_valid(get_meta("magu_acao"))):
		return
	if source_kind == "fruit" and _fruit_damage_lock_timer > 0.0:
		return # validação autoritativa: cliente não pula a recuperação por RPC
	if source_id == "tori_tori_phoenix":
		if source_kind != "fruit" or current_fruit_id != source_id or not _phoenix.pode(slot): return
	if source_id == "rocket":
		if source_kind != "fruit" or not _rocket.autorizar(slot, aim, origin, cast_token):
			return
	if source_id == "ope_ope":
		if source_kind != "fruit" or not _autorizar_ope(slot, aim, origin, cast_token):
			return
	if source_id == "bara_bara":
		if source_kind != "fruit" or not BARA_NET.authorize(self, slot, aim, origin, cast_token):
			return
	# BUKI BUKI: o cast É o saque da arma. É AQUI, na cópia autoritativa, que a
	# munição do servidor é carregada — o cliente não escolhe quantas balas tem.
	# Já sai com uma a menos porque o próprio saque dispara o primeiro tiro.
	# ⚠️ SEGUNDO ESCRITOR do estado autoritativo da Buki — o gêmeo da armadilha
	# de 2026-08-11. Está morto pelo caminho de input (begin_charge e
	# cast_skill_slot desviam para `_buki_empunhar` e RETORNAM), mas continua
	# alcançável pelo RPC `_net_cast` vindo de um cliente. Some com ele e o
	# servidor volta a recusar tiro por caminho que ninguém lembra de testar.
	if source_kind == "fruit" and source_id == "buki_buki":
		_buki.servidor_sacar(slot)
	if multiplayer.has_multiplayer_peer():
		_net_play_cast.rpc(slot, aim, origin, charge, cast_token, source_kind, source_id)
	else:
		_net_play_cast(slot, aim, origin, charge, cast_token, source_kind, source_id)

# MIRA -> src/player/mira.gd (Fase 9). Estas três continuam aqui como cascas
# porque são a API que testes e componentes já conhecem.
func _muzzle_pos(side: int) -> Vector3:
	return _mira.boca_da_pistola(_pistols, side, _cam)

func _aim_target_point() -> Vector3:
	return _mira.ponto_de_mira(_cam, aim_assist)

func _aim_assist_target(cam_pos: Vector3, fwd: Vector3) -> Node3D:
	return _mira.alvo_alinhado(cam_pos, fwd)

@rpc("any_peer", "reliable")
func _net_bullet_req(aim: Vector3, origin: Vector3, arma: String) -> void:
	if multiplayer.is_server():
		var cid = multiplayer.get_remote_sender_id()
		if cid != 0 and cid != get_multiplayer_authority(): return
		_do_server_bullet(aim, origin, arma)

# `arma` != "" -> é um tiro da Buki Buki, e aí o SERVIDOR é quem manda na munição.
func _do_server_bullet(aim: Vector3, origin: Vector3, arma: String = "") -> void:
	if arma != "":
		# Sem bala no contador do servidor, nenhum tiro sai — nem visual, nem
		# DamageZone. Cliente adulterado não ganha munição infinita.
		if not _buki.servidor_autoriza_tiro(arma):
			return
	if multiplayer.has_multiplayer_peer():
		_net_bullet_play.rpc(aim, origin, arma)
	else:
		_net_bullet_play(aim, origin, arma)

@rpc("any_peer", "call_local", "reliable")
func _net_bullet_play(aim: Vector3, origin: Vector3, arma: String) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender = multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1: return
	if arma != "":
		# BUKI: o disparo tem cara de arma (fogacho, cápsula, projétil) e o dano
		# por bala vem do `Balance`. O PENTE INTEIRO é uma conjuração só — as 100
		# balas do minigun dividem um orçamento, senão a arma com mais munição
		# seria automaticamente a mais forte.
		var spec_b := _spec_do_disparo("buki_buki", arma)
		BukiFX.disparo(get_tree().current_scene, origin, aim, arma, spec_b.dano, self, null, spec_b)
		return
	if get_tree() and get_tree().current_scene:
		AudioFX.gunshot(get_tree().current_scene, origin, randf_range(0.95, 1.12))
	# ⚠️ AQUI MORAVAM TRÊS LITERAIS (`8.0`, `25.0`, `8.0`) escritos à mão, que
	# ignoravam a tabela de skills — ela dizia 20 para a Mera Z e 28 para a Hie Z,
	# e nenhum dos dois era usado. Com 8 balas por rajada, o erro se multiplicava.
	var spec_r := _spec_do_disparo(current_fruit_id, "Z")
	if current_fruit_id == "hie_hie":
		IceFX.bullet(get_tree().current_scene, origin, aim, spec_r.dano, self, spec_r)
	elif current_fruit_id == "yami_yami":
		YamiFX.bullet(get_tree().current_scene, origin, aim, spec_r.dano, self, spec_r)
	else:
		FireFX.bullet(get_tree().current_scene, origin, aim, spec_r.dano, self, spec_r)

# ---------------------------------------------------- CONJURAÇÃO DE DISPARO
# A spec do pente/rajada em curso. Uma rajada de 8 balas e um pente de 100 são
# UMA conjuração, não 16 ou 100 — é isso que dá teto a elas.
#
# ⚠️ Só o valor do SERVIDOR importa: a `DamageZone` sai cedo em clientes, então
# cada peer ter o seu `cast_id` é inofensivo. Não vale a pena sincronizar.
var _spec_disparo: DamageSpec = null
var _spec_disparo_chave: String = ""

## Abre (ou reaproveita) a conjuração do disparo sustentado deste slot.
## Troca de arma ou de fruta abre uma conjuração nova — a chave carrega as duas.
func _spec_do_disparo(fruta: String, slot: String) -> DamageSpec:
	var chave := fruta + "/" + slot
	if _spec_disparo != null and _spec_disparo_chave == chave:
		return _spec_disparo
	var s := Balance.novo(fruta, slot, escala_de_dano_da_fruta(fruta))
	if s == null:
		s = DamageSpec.avulso(0.0)
	_spec_disparo = s
	_spec_disparo_chave = chave
	return s

## Fecha a conjuração de disparo. Chamado ao guardar a arma, ao parar a rajada e
## ao morrer: sem isto o pente seguinte nasceria com o orçamento do anterior já
## gasto, e a segunda arma sacada não machucaria ninguém.
func encerrar_disparo() -> void:
	if _spec_disparo != null:
		CombatResolver.encerrar(_spec_disparo.cast_id)
	_spec_disparo = null
	_spec_disparo_chave = ""

@rpc("any_peer", "call_local", "reliable")
func _net_play_cast(slot: String, aim: Vector3, origin: Vector3, charge: float = 0.0,
		cast_token: int = 0, source_kind: String = "", source_id: String = "") -> void:
	if multiplayer.has_multiplayer_peer():
		var sender = multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1: return
	if source_kind == "fruit" and source_id in ["ope_ope", "bara_bara", "rocket"]:
		set_meta("ope_pending_until" if source_id == "ope_ope" else "bara_pending_until", 0)
		if _is_authority and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			gastar_energia(custo_de_energia_do_cast(slot))
			trigger_skill_cooldown(slot)
	_fire_skill(slot, aim, origin, charge, cast_token, source_kind, source_id)

var _spawned_skills_container: Node3D

func _exit_tree() -> void:
	BARA_NET.cleanup(self)
	if is_instance_valid(_spawned_skills_container):
		_spawned_skills_container.queue_free()

func _get_skills_container() -> Node3D:
	if not is_instance_valid(_spawned_skills_container):
		_spawned_skills_container = Node3D.new()
		_spawned_skills_container.name = "Skills_" + name
		var sc = get_tree().current_scene
		var pai: Node = sc if sc else self
		# Entra na árvore NO MESMO QUADRO (06/10/2026). Era sempre `call_deferred`: o
		# PRIMEIRO golpe da sessão criava os efeitos num contêiner ainda fora da
		# árvore, e todo `global_position` deles falhava ("!is_inside_tree" no Hiken
		# da Mera; a Pika e a Goro tinham contorno próprio). Deferido só quando o pai
		# ainda está montando os filhos, que é o caso em que o Godot recusa o add_child.
		if pai.is_inside_tree() and pai.is_node_ready():
			pai.add_child(_spawned_skills_container)
		else:
			pai.add_child.call_deferred(_spawned_skills_container)
	return _spawned_skills_container

# ⚠️ A LIMPEZA PRECISA ATRAVESSAR A REDE (2026-08-22).
#
# `clear_spawned_skills()` varre o contêiner `Skills_<jogador>` do peer em que
# roda — e `_fire_skill` é a PRESENTATION do golpe: ele roda em TODOS os peers,
# então cada um tem a sua cópia dos efeitos deste jogador. Limpar só localmente
# deixava as cópias vivas em todo mundo menos em quem trocou de fruta.
#
# Sintoma medido com a sonda de dois processos: os 45 vagalumes da Mera Mera
# continuavam no HOST depois de o cliente trocar de fruta, e detonavam minutos
# depois, já durante outra fruta. É o "quando o servidor morre ou troca de fruta
# a fruta não desespawna as skills" do relato, visto do outro lado.
#
# `call_local` para o pedido valer também em quem chamou; sem peer roda direto.
func limpar_skills_em_todos() -> void:
	if multiplayer.has_multiplayer_peer():
		_net_limpar_skills.rpc()
	else:
		clear_spawned_skills()

@rpc("any_peer", "call_local", "reliable")
func _net_limpar_skills() -> void:
	clear_spawned_skills()

func clear_spawned_skills() -> void:
	if _phoenix != null: _phoenix.cancelar()
	if _rocket != null: _rocket.cancelar()
	if is_instance_valid(_spawned_skills_container):
		for c in _spawned_skills_container.get_children():
			c.queue_free()

# Presentation da skill (roda em todos): VFX pela fruta/estilo. A DamageZone criada
# dentro só aplica dano no SERVIDOR (ver DamageZone).
## ARENA (decisão do dono, 06/10/2026): o botão do menu do M pede o Kit do Builder ao
## SERVIDOR, que equipa em todos pelo mesmo caminho da fruta colhida (`FruitNet`).
func pedir_kit_do_builder() -> void:
	combat_mode = "fruit"
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_servidor_dar_kit(get_multiplayer_authority())
	else:
		_net_pedir_kit.rpc_id(1)


@rpc("any_peer", "reliable")
func _net_pedir_kit() -> void:
	if not multiplayer.is_server():
		return
	var cid := multiplayer.get_remote_sender_id()
	if cid != get_multiplayer_authority():
		return
	_servidor_dar_kit(cid)


func _servidor_dar_kit(peer_id: int, fruta: String = KitDoBuilder.ID) -> void:
	if not KitDoBuilder.e_do_builder(fruta) or not KitDoBuilder.disponivel(fruta):
		return
	FruitNet.pickup(fruta, peer_id)


## ARENA: uma FRUTA do Builder (ex.: Noro Noro no Mi) pedida pelo menu do M — o mesmo
## caminho do kit, com o id da fruta (o servidor confere que ela existe e tem skill).
func pedir_fruta_do_builder(fruta: String) -> void:
	combat_mode = "fruit"
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_servidor_dar_kit(get_multiplayer_authority(), fruta)
	else:
		_net_pedir_fruta_do_builder.rpc_id(1, fruta)


@rpc("any_peer", "reliable")
func _net_pedir_fruta_do_builder(fruta: String) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	_servidor_dar_kit(multiplayer.get_remote_sender_id(), fruta)


## "Carregar e soltar" (06/10/2026): a tecla subiu. Quem decide é a autoridade do corpo
## (continuar, ou cancelar se ainda não chegou ao ponto de segurar); o servidor espalha
## para todos os peers, onde o executor daquela tecla segue ou para.
var _execs_do_kit := {}          # tecla → ExecutorDeSkill deste corpo (em cada peer)

## `aim`/`origem` = a mira NO SOLTAR (07/10/2026): o Z carregado da Pika sai para onde o
## retículo está quando a tecla sobe, não para onde estava ao apertar.
func pedir_soltar_do_kit(slot: String, cancelar: bool, aim := Vector3.ZERO, origem := Vector3.ZERO) -> void:
	if not multiplayer.has_multiplayer_peer():
		_net_soltar_kit(slot, cancelar, aim, origem)
	elif multiplayer.is_server():
		_net_soltar_kit.rpc(slot, cancelar, aim, origem)
	else:
		_net_pedir_soltar_kit.rpc_id(1, slot, cancelar, aim, origem)


@rpc("any_peer", "reliable")
func _net_pedir_soltar_kit(slot: String, cancelar: bool, aim := Vector3.ZERO, origem := Vector3.ZERO) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	if not _vetor_de_cast_finito(aim) or not _vetor_de_cast_finito(origem) \
			or global_position.distance_to(origem) > 4.5:
		aim = Vector3.ZERO                  # mira inválida: o golpe sai com a do aperto
	_net_soltar_kit.rpc(slot, cancelar, aim, origem)


@rpc("any_peer", "call_local", "reliable")
func _net_soltar_kit(slot: String, cancelar: bool, aim := Vector3.ZERO, origem := Vector3.ZERO) -> void:
	if multiplayer.has_multiplayer_peer():
		var de := multiplayer.get_remote_sender_id()
		if de != 0 and de != 1:
			return
	var e: Variant = _execs_do_kit.get(slot)
	if not is_instance_valid(e):
		return
	if cancelar:
		(e as ExecutorDeSkill).cancelar()
	elif str((e as ExecutorDeSkill).skill.get("ativacao", {}).get("modo", "")) == "Sustentar":
		(e as ExecutorDeSkill).soltar()      # "Sustentar": soltar encerra a skill
	else:
		if aim.length_squared() > 0.0001 and _vetor_de_cast_finito(aim) and _vetor_de_cast_finito(origem):
			var ponto := AlvosDeGolpe.ponto_mirado(get_world_3d(), origem, aim, 60.0, [get_rid()])
			(e as ExecutorDeSkill).mirar_de_novo(aim, ponto)
		(e as ExecutorDeSkill).segurando = false


## Lentidão de skill (Noro Noro, 06/10/2026): quem move este corpo é o cliente dono, e
## só o servidor sabe do acerto — o servidor espalha o fator para todos os peers.
## Congelamento da Hie em rede (07/10/2026, "todos os golpes congelam 0,7 s"): o acerto
## é do servidor; o corpo é do cliente dono. O servidor espalha para todos: o dono trava
## (`is_frozen`, que a locomoção respeita) e todos veem o bloco de gelo.
func congelar_em_rede(segundos: float) -> void:
	if get_meta("magu_cao_ativo", false):
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_net_congelar.rpc(segundos)


@rpc("any_peer", "call_remote", "reliable")
func _net_congelar(segundos: float) -> void:
	if get_meta("magu_cao_ativo", false):
		return
	if multiplayer.get_remote_sender_id() != 1:
		return
	IceFX.congelar(self, clampf(segundos, 0.0, 10.0), false)


func aplicar_lentidao_em_rede(fator: float, segundos: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		Lentidao.aplicar_local(self, fator, segundos)
		return
	_net_lentidao.rpc(fator, segundos)


@rpc("any_peer", "call_local", "reliable")
func _net_lentidao(fator: float, segundos: float) -> void:
	if get_meta("magu_cao_ativo", false):
		return
	if multiplayer.has_multiplayer_peer():
		var de := multiplayer.get_remote_sender_id()
		if de != 0 and de != 1:
			return
	Lentidao.aplicar_local(self, clampf(fator, 0.02, 1.0), clampf(segundos, 0.0, 30.0))


## Pedido de movimento de uma skill do Builder (chamado a cada quadro pelo executor).
func definir_movimento_de_skill(vel: Vector3, vertical: bool, parar: bool = false) -> void:
	if parar:
		_mov_skill_quadro = -100
		_mov_skill_vel = Vector3.ZERO
		return
	_mov_skill_vel = vel
	_mov_skill_vertical = vertical
	_mov_skill_quadro = Engine.get_physics_frames()


func _movimento_de_skill_ativo() -> bool:
	return Engine.get_physics_frames() - _mov_skill_quadro <= 2


## Skill do Builder com "Flutuar" (Pika refeita no editor, 06/10/2026): do começo ao fim
## dela o corpo não cai (golpe no ar). Quem liga e desliga é o executor.
func definir_flutuar(sim: bool) -> void:
	_flutuar_por_skill = sim
	if sim:
		velocity.y = 0.0


## VFX "Cometa" do Builder: o corpo VIRA luz (some) enquanto o bloco dura. Visual: roda
## em todos os peers, como o próprio executor.
func ocultar_corpo_por_skill(sim: bool) -> void:
	if _char_model != null:
		_char_model.visible = not sim


## Clipe de um bloco de Animação do Builder: vira uma pose do animador procedural
## (o catálogo do Builder é fechado; a tabela fica em `KitDoBuilder.POSES`).
##
## 07/10/2026 (pedido do dono: "corrigir as animações atuais"): a prévia tocava um clipe e
## o jogo ligava uma pose antiga (`KitDoBuilder.POSES`) — coisas diferentes. Agora é o
## clipe bakeado da lista do editor (`ClipesDeSkill`), no TEMPO do bloco, pelo caminho do
## roll do Q (o "clipe de ação" do animador, que já vai pela rede). A prévia aplica o mesmo.
const ClipesDeSkill := preload("res://src/skills_builder/clipes_de_skill.gd")
var _clipe_de_skill := ""
var _tempo_clipe_de_skill := 0.0
var _peso_clipe_de_skill := 1.0

func tocar_animacao_de_skill(clipe: String, tempo: float, _velocidade: float, intensidade: float) -> void:
	_clipe_de_skill = ClipesDeSkill.caminho(clipe)
	_tempo_clipe_de_skill = tempo
	_peso_clipe_de_skill = clampf(intensidade, 0.0, 1.0)


func parar_animacao_de_skill() -> void:
	_clipe_de_skill = ""


## KIT DO BUILDER (06/10/2026): a skill da tecla roda no `ExecutorDeSkill`, no contêiner
## de golpes deste jogador. Presentation em todos os peers; dano só no servidor.
func _lancar_do_kit(slot: String, aim: Vector3, origin: Vector3, fruta: String = KitDoBuilder.ID) -> void:
	var s := KitDoBuilder.skill(slot, fruta)
	if s.is_empty():
		return
	var fora: Array[RID] = [get_rid()]
	var ponto := AlvosDeGolpe.ponto_mirado(get_world_3d(), origin, aim, 60.0, fora)
	print("🛠 %s: %s [%s]" % [KitDoBuilder.nome(fruta).to_upper(), s.identificacao.nome, slot])
	# Semente da chuva (07/10/2026): mira e origem viajam iguais na rede.
	var escala := escala_de_dano_da_fruta(fruta, true)
	_execs_do_kit[slot] = ExecutorDeSkill.lancar(_get_skills_container(), self, s, aim,
		escala, ponto, hash([aim, origin]))


func _fire_skill(slot: String, aim: Vector3, origin: Vector3, charge: float = 0.0,
		cast_token: int = 0, source_kind: String = "", source_id: String = "") -> void:
	var variant: int = ["Z", "X", "C", "V"].find(slot)
	if variant < 0:
		variant = 0

	if _animator:
		_animator.trigger_kill()

	var world := _get_skills_container()

	var cast_mode := source_kind if source_kind in ["fruit", "style"] else combat_mode
	var cast_source := source_id
	if cast_source == "":
		cast_source = estilo_atual() if cast_mode == "style" else current_fruit_id
	# ANEXO VISUAL (15/11/2026): anel de ativação da cor da fruta sob o jogador, como nas frutas do mod. Medido na arena: 26 de 59 golpes mudavam <4% da imagem
	# (golpes junto ao corpo, sem nenhuma marca de que a técnica disparou). Só desenho; o custo é um tween.
	if cast_mode == "fruit" and cast_source != "":
		PoderDaFruta.ativacao(self, cast_source, ENERGY_SKILL)
	var cast_com_duracao_propria := false

	if cast_mode == "style":
		var active_style: String = cast_source
		if not FightingStyles.STYLES.has(active_style):
			return
		var sdata: Dictionary = FightingStyles.STYLES[active_style]["skills"][slot]
		# O dano vem do `Balance`, não da tabela do estilo — mesma fonte única das
		# frutas, para o corpo a corpo não ficar numa escala própria.
		var spec_e := Balance.spec_de_estilo(active_style, slot).para_cast()
		print("🥊 ESTILO ", active_style.to_upper(), ": ", sdata.get("nome", slot))
		FightingStyles.cast(world, active_style, variant, origin, aim, spec_e.dano, self,
			spec_e, cast_token)
		cast_com_duracao_propria = active_style == "pacifista"
	elif KitDoBuilder.pelo_builder(cast_source, slot):
		_lancar_do_kit(slot, aim, origin, cast_source)
	else:
		var fruit_skills := SkillSystem.get_fruit_skills()
		# ⚠️ Aqui existia `else "gomu_gomu"` — um fallback MUDO, e ele era a causa
		# de dois bugs relatados jogando:
		#   • pegar uma fruta sem skills (hito_hito_nika, tori_tori_phoenix)
		#     dava os golpes da Gomu Gomu com o nome da outra fruta na HUD;
		#   • depois de MORRER o jogador larga a fruta (`current_fruit_id = ""`) e
		#     passava a sair Gomu Gomu do nada, como se tivesse ganhado uma fruta.
		# Sem fruta não há poder de fruta. O golpe não sai, e diz por quê.
		if not fruit_skills.has(cast_source):
			if cast_source == "":
				print("🚫 Sem Akuma no Mi — pegue uma fruta numa árvore para usar poderes.")
			elif cast_source == "sem_fruta":
				print("🚫 Você comeu a Fruta da Normalidade. Suas skills não fazem nada.")
			else:
				push_warning("[Fruta] '%s' não tem skills no SkillSystem" % cast_source)
				print("🚫 A fruta '%s' ainda não tem poderes implementados." % cast_source)
			return
		var fid := cast_source
		var sdata: Dictionary = fruit_skills[fid][slot]
		var cor: Color = sdata.get("cor", Color.WHITE)

		# A CONJURAÇÃO nasce aqui. `para_cast()` devolve uma cópia da spec com um
		# `cast_id` novo, e é ele que amarra todas as hitboxes deste golpe a um
		# orçamento só — ver src/combat/CombatResolver.gd.
		#
		# ⚠️ A spec tem de ser criada UMA vez por golpe e descer inteira até o
		# efeito. Deixar cada hitbox pedir a sua daria um orçamento por hitbox,
		# que é exatamente o teto que NÃO existia antes desta refatoração.
		var spec := Balance.novo(fid, slot, escala_de_dano_da_fruta(fid))
		if spec == null:
			push_warning("[Balance] '%s/%s' não está na tabela de dano" % [fid, slot])
			spec = DamageSpec.avulso(0.0)
		var dano: float = spec.dano
		print("⚡ FRUTA ", fid.to_upper(), ": ", sdata.get("nome", slot))

		match fid:
			"tori_tori_phoenix":
				_phoenix.executar(slot, aim, spec)
				cast_com_duracao_propria = true
			"magu_magu":
				preload("res://src/effects/magu/tecnica_magu.gd").lancar(world, self, slot, aim, spec, cast_token)
				cast_com_duracao_propria = true
			"rocket":
				_rocket.iniciar(slot, aim, cast_token)
				cast_com_duracao_propria = true
			"ope_ope":
				OPE.cast(world, slot, aim, origin, self, spec, cast_token)
				cast_com_duracao_propria = true
			# ⚠️ O V DA GOMU NÃO É MAIS UM GOLPE — é a transformação Gear 2
			# (decisão do dono, 2026-08-27). Entra ANTES do `GomuFX.cast` porque
			# não cria hitbox nenhuma: é estado, não conjuração. O Red Hawk, que
			# era o V, segue vivo em `GomuFX._red_hawk` esperando o conjunto de
			# golpes transformado.
			"gomu_gomu":
				if slot == "V":
					if _gear2:
						_gear2.ativar()
				else:
					GomuFX.cast(world, origin, aim, variant, dano, self, spec)
			"suna_suna": SandFX.cast(world, origin, aim, variant, dano, self, spec)
			"mera_mera": FireFX.cast(world, origin, aim, variant, dano, self, charge, spec)
			"hie_hie":   IceFX.cast(world, origin, aim, variant, dano, self, spec)
			"goro_goro": GoroFX.cast(world, origin, aim, variant, dano, self, spec, charge)
			"yami_yami": YamiFX.cast(world, origin, aim, variant, dano, self, spec)
			"bara_bara":
				BARA.cast(world, slot, aim, origin, self, spec, cast_token)
				cast_com_duracao_propria = true
			"gura_gura": GuraFX.cast(world, origin, aim, variant, dano, self, charge, spec)
			"bomu_bomu": BomuFX.cast(world, origin, aim, variant, dano, self, charge, spec)
			"pika_pika":
				PikaFX.cast(world, origin, aim, variant, dano, self, spec, cast_token)
				# O C vive enquanto a tecla estiver pressionada (máximo 3,7 s).
				# O timeout genérico de 0,3 s faria o próximo physics frame abortá-lo.
				if slot == "C":
					cast_com_duracao_propria = true
			"buki_buki":
				# SAQUE DA ARMA. Roda em TODOS os peers (este método é a
				# presentation do cast), então o adversário vê a arma aparecer
				# na mão / o corpo virar canhão. O tiro do saque sai junto.
				_buki_mostrar_arma(["Z", "X", "C", "V"][variant])
				BukiFX.cast(world, origin, aim, variant, dano, self, spec)
			_: _generic_vfx(cor, aim, origin)

	# Fim da janela de interrupção DESTE golpe. Só apaga se nenhum cast novo tiver
	# começado nesse meio-tempo (senão engolia a skill seguinte — ver _cast_token).
	if not cast_com_duracao_propria:
		var tok := _cast_token
		get_tree().create_timer(0.3).timeout.connect(func():
			if _cast_token == tok:
				set_meta("is_casting", false))

# VFX genérico para frutas ainda sem efeito dedicado.
func _generic_vfx(cor: Color, aim: Vector3, origin: Vector3) -> void:
	var vfx := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	vfx.mesh = sphere
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(cor.r, cor.g, cor.b, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = 3.5
	vfx.material_override = m
	vfx.position = origin
	get_tree().current_scene.add_child(vfx)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(vfx, "position", origin + aim * 8.0, 0.45)
	tw.tween_property(vfx, "scale", Vector3.ONE * 5.0, 0.45)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.set_parallel(false)
	tw.tween_callback(vfx.queue_free)

func cast_skill(cor: Color) -> void:
	cast_skill_slot("Z")

# DEBUG (tecla T): cicla entre todas as frutas p/ testar as skills rapidamente.
func _cycle_fruit() -> void:
	var ids: Array = SkillSystem.get_fruit_skills().keys()
	var i: int = ids.find(current_fruit_id)
	var nxt: String = ids[(i + 1) % ids.size()]
	combat_mode = "fruit"       # garante que o cast use a fruta (não o estilo)
	equip_fruit(nxt)
	print("🔀 Fruta de teste: ", nxt)

func equip_fruit(fruit_id: String) -> void:
	if _phoenix != null: _phoenix.cancelar()
	if (has_meta("magu_acao") and is_instance_valid(get_meta("magu_acao"))):
		get_meta("magu_acao").encerrar()
	# ⚠️ SAÍDA POR TROCA DE FRUTA. O Gear 2 é da Gomu Gomu; sair dela tem de
	# largar a transformação junto, senão a pele e o chapéu ficam num personagem
	# que já é de outra fruta.
	if _gear2 and _gear2.esta_ativo():
		_gear2.desativar()
	# Mesma regra para a camuflagem da Suke: trocar de fruta invisível deixava o dreno
	# de energia correndo com a fruta nova (medido em 03/10/2026, test_frutas_na_historia).
	if _invisivel and fruit_id != "suke_suke":
		revelar_invisibilidade()
	# ⚠️ A FRUTA SOME DA ÁRVORE AO SER EQUIPADA — por QUALQUER caminho.
	#
	# Isto vive aqui, e não no `pickup_fruit`, porque equipar tem TRÊS entradas e
	# só uma delas escondia a fruta:
	#   • `TreeAndFruitGenerator.pickup_fruit` (encostar na árvore) — escondia;
	#   • `Main.gd:114`, a fruta de nascença — NÃO escondia;
	#   • `FruitNet._apply_pickup` e o ciclo de debug — dependiam do caminho.
	#
	# Sintoma medido em 2026-08-12: o jogador nascia com `suna_suna` e a
	# `suna_suna` continuava VISÍVEL na árvore. Em partida de dois, os dois
	# nasciam com ela e o mapa ainda oferecia uma terceira — o oposto do
	# equilíbrio que a regra existe para garantir.
	#
	# A fruta ANTERIOR volta para a árvore: trocar de poder devolve o antigo ao
	# mapa, exatamente como morrer devolve.
	if fruit_id != current_fruit_id:
		limpar_skills_em_todos()
		if current_fruit_id != "":
			TreeAndFruitGenerator.respawn_fruit(current_fruit_id)
		if fruit_id != "":
			TreeAndFruitGenerator.hide_fruit(fruit_id)

	_fruit_cooldowns.clear()
	current_fruit_id = fruit_id
	
	if fruit_id == "gura_gura":
		scale = Vector3(2.0, 2.0, 2.0)
	else:
		scale = Vector3.ONE
		
	# Troca automática de aparência ao comer/equipar uma Akuma no Mi
	var new_cid := ""
	match fruit_id:
		"mera_mera": new_cid = "ace"
		"yami_yami": new_cid = "blackbeard"
		"suna_suna": new_cid = "crocodile"
		"goro_goro": new_cid = "nami"
		"bara_bara": new_cid = "buggy"
		"gomu_gomu": new_cid = "base"
	# Com o elenco trancado a aparência não muda — checa ANTES de anunciar, senão
	# o log diz "transformado em crocodile" e carrega o base logo abaixo.
	if new_cid != "" and not ELENCO_LIBERADO.has(new_cid):
		new_cid = ""
	if new_cid != "" and character_id != new_cid:
		print("🔄 Troca automática de aparência: comendo a fruta [", fruit_id, "] -> transformado em [", new_cid, "]!")
		_setup_character_model(new_cid)
	_disparo.desligar_yami()
	# Trocou de fruta -> a arma da Buki cai da mão (e o slot dela esfria).
	_buki_guardar()
	_buki_mostrar_arma("")
	set_meta("yami_black_hole_active", false)
	set_meta("yami_kurouzu_active", false)
	var all_passives := FruitPassiveSystem.get_all_passives()
	# Sem passiva (o Kit do Builder, ou sem fruta), o corpo volta ao normal. Antes a
	# velocidade e o pulo da fruta ANTERIOR ficavam (06/10/2026).
	speed_multiplier = 1.0
	jump_multiplier = 1.0
	if all_passives.has(fruit_id):
		var p_data: Dictionary = all_passives[fruit_id]
		speed_multiplier = float(p_data.get("speed_mod", 1.0))
		jump_multiplier = float(p_data.get("jump_mod", 1.0))
		print("⚡ Fruta Equipada: ", fruit_id, " | Passiva: ", p_data.get("nome", ""), " [Speed: x", speed_multiplier, " Jump: x", jump_multiplier, "]")

	# Atualiza a barra de tecnicas para a fruta equipada — vale para QUALQUER
	# caminho de coleta (esfera no chao OU fruta na arvore), consertando o caso
	# em que o poder era ganho mas a HUD nao refletia.
	# HUD só reflete a fruta do MEU player (equipar em player remoto não mexe no meu HUD).
	var hud := get_tree().get_first_node_in_group("hud")
	if _is_authority and hud and hud.has_method("update_skills_for_fruit"):
		hud.update_skills_for_fruit(fruit_id)

func _alvo_mais_proximo(max_dist: float) -> Node3D:
	return _mira.mais_proximo(max_dist)

# ============================================================================
#  BUKI BUKI NO MI — a fruta virou FPS (regra nova do dono, 2026-08-11)
#
#  MÁQUINA DE ESTADO da arma, em quatro transições e nada mais:
#
#    mãos livres --[tecla do slot]--> EMPUNHADA(slot)   (+ tiro do saque)
#    EMPUNHADA(a) --[tecla de outro slot b]--> EMPUNHADA(b) e (a) EM RECARGA
#    EMPUNHADA(a) --[tecla do mesmo slot a]--> mãos livres e (a) EM RECARGA
#    EMPUNHADA(a) --[munição = 0]--> mãos livres e (a) EM RECARGA
#
#  Ou seja: largar a arma SEMPRE custa a recarga do slot largado — seja por
#  troca, por desistência ou por bala acabada. É isso que obriga o rodízio.
#
#  O modelo é o toggle da pistola da Yami (`DisparoSustentado.atualizar_yami`), que já fazia
#  "aperta, a arma fica, botão esquerdo atira, outra skill guarda" — a Buki só
#  acrescenta munição por cima e sobe pros quatro slots.
# ============================================================================

func _buki_ativa() -> bool:
	return combat_mode == "fruit" and current_fruit_id == "buki_buki"

## Munição/arma para a HUD. Ver src/ui/AmmoHud.gd.
func buki_arma() -> String:
	return _buki_weapon
func buki_municao() -> int:
	return _buki_municao
func buki_municao_max() -> int:
	return _buki.municao_max()

# EMPUNHAR / GUARDAR: a regra mora no componente; aqui fica o que é do Player
# (autoridade e supressão) e o encanamento de rede.
func _buki_empunhar(slot: String) -> void:
	_buki.empunhar(slot, _is_authority, is_suppressed)

func _buki_guardar() -> void:
	_buki.guardar()

@rpc("any_peer", "reliable")
func _net_buki_sacar_req(slot: String) -> void:
	if multiplayer.is_server():
		var cid = multiplayer.get_remote_sender_id()
		if cid != 0 and cid != get_multiplayer_authority(): return
		_do_server_buki_sacar(slot)

# SERVIDOR: guarda qual arma este corpo empunha e com quanta munição, e manda
# todos os peers mostrarem a arma. O servidor é quem valida cada tiro depois.
func _do_server_buki_sacar(slot: String) -> void:
	if not _buki.servidor_sacar(slot):
		return
	if multiplayer.has_multiplayer_peer():
		_net_buki_sacar.rpc(slot)
	else:
		_net_buki_sacar(slot)

@rpc("any_peer", "call_local", "reliable")
func _net_buki_sacar(slot: String) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender = multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1: return
	# Saque = pente novo = conjuração nova. Encerrar ANTES de mostrar a arma
	# garante que sacar a MESMA arma duas vezes devolva o orçamento cheio (a
	# troca entre armas diferentes já seria pega pela chave de `_spec_do_disparo`).
	encerrar_disparo()
	_buki_mostrar_arma(slot)

@rpc("any_peer", "reliable")
func _net_buki_guardar_req() -> void:
	if multiplayer.is_server():
		var cid = multiplayer.get_remote_sender_id()
		if cid != 0 and cid != get_multiplayer_authority(): return
		_do_server_buki_guardar()

# SERVIDOR: zera a munição autoritativa (nenhum tiro mais é aceito) e manda todo
# mundo tirar a arma da mão.
func _do_server_buki_guardar() -> void:
	_buki.servidor_guardar()
	if multiplayer.has_multiplayer_peer():
		_net_buki_guardar.rpc()
	else:
		_net_buki_guardar()

@rpc("any_peer", "call_local", "reliable")
func _net_buki_guardar() -> void:
	_buki_mostrar_arma("")
	# Arma guardada, pente encerrado: o próximo saque começa com o orçamento cheio.
	encerrar_disparo()

func _buki_apontar_canhao() -> void:
	_buki.apontar_canhao(_is_authority, _pitch, _yaw, net_facing)

var equipped_weapon: String = ""

# ============================================================================
#  SISTEMA DE ITENS / EQUIPAMENTOS
# ============================================================================

func equip_item(item_node: Node3D) -> void:
	if item_node == null: return
	if _rig.item_handle == null: return
	
	var p = item_node.get_parent()
	if p:
		p.remove_child(item_node)
	
	_rig.item_handle.add_child(item_node)
	item_node.position = Vector3.ZERO
	item_node.rotation = Vector3.ZERO
	
	if item_node is SwordPickup:
		equipped_weapon = "sword"
		print("[Player] Arma equipada: sword")


# ============================================================================
#  A YORU — sacar, guardar, e onde mora o fio
# ============================================================================
#  A espada saiu do spawn do mapa em 2026-08-23 e não voltou. Para o dono poder
#  conferir as animações, o ponto de pega e o choque de espadas sem alterar a
#  partida de todo mundo, ela é sacada por TECLA (Y), não catada no chão.
#
#  A ligação pedida ("nomeie o cabo como handle e a mão do jogador também,
#  depois os ligue") acontece em uma linha, e é literal: `YoruSword.ligar_na_mao`
#  põe o nó `handle` da espada como filho do nó `Hand_R` do rig. Não há offset
#  em lugar nenhum do caminho — mover a pega é mover um dos dois nós.
var _yoru: YoruSword = null

## A lâmina em si, para quem precisa armar as zonas do fio. Quem chama é
## `Melee.golpear`, no fim do startup de cada corte.
func lamina_da_espada() -> SwordBlade:
	if _yoru == null or not is_instance_valid(_yoru):
		return null
	return _yoru.lamina


func sacar_ou_guardar_espada() -> void:
	set_combat_mode("fruit" if combat_mode == "sword" else "sword")


func _toggle_yoru_visual() -> void:
	if _yoru != null and is_instance_valid(_yoru):
		# ⚠️ SAI DA ÁRVORE AGORA, e só depois é liberada. `queue_free` sozinho
		# deixa o nó pendurado na mão até o fim do quadro: quem olhasse a mão no
		# mesmo quadro ainda veria uma espada, e sacar de novo antes da varredura
		# criaria uma segunda ("Yoru2") ao lado da que está morrendo. O
		# `remove_child` torna o estado da mão verdadeiro no instante da troca.
		var mao_atual := _yoru.get_parent()
		if mao_atual != null:
			mao_atual.remove_child(_yoru)
		_yoru.queue_free()
		_yoru = null
		equipped_weapon = ""
		if _proc_anim and _proc_anim.has_method("soltar_lamina_do_rastro"):
			_proc_anim.soltar_lamina_do_rastro()
		print("[Yoru] guardada")
		return

	var mao: Node3D = _rig.item_handle
	if mao == null or not is_instance_valid(mao):
		push_warning("[Yoru] o rig ainda não tem a mão (Hand_R) montada")
		return
	_yoru = YoruSword.ligar_na_mao(mao)
	if _yoru == null:
		return
	# O dono da lâmina é quem empunha: é por ele que a `SwordBlade` sabe quem
	# NÃO pode ser acertado e quem tem o golpe cancelado num choque.
	if _yoru.lamina:
		_yoru.lamina.dono = self
	# O rastro do golpe passa a ser desenhado ENTRE A GUARDA E A PONTA da Yoru.
	# Sem isto ele sai do cotovelo até um ponto chutado, e em tela lê como uma
	# chapa branca saindo do peito apontando para outro lado que não a espada.
	if _proc_anim and _proc_anim.has_method("usar_lamina_no_rastro"):
		_proc_anim.usar_lamina_no_rastro(_yoru.guarda, _yoru.ponta, _yoru)
	equipped_weapon = "sword"
	print("[Yoru] sacada — handle sobre %s" % mao.name)


func bara_snapshot(data: Dictionary) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_net_bara_snapshot.rpc(data)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _net_bara_snapshot(data: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != 1: return
	BARA_NET.receive(self, data)

func bara_finished(token: int) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_net_bara_finished.rpc(token)

@rpc("any_peer", "call_remote", "reliable")
func _net_bara_finished(token: int) -> void:
	if multiplayer.get_remote_sender_id() != 1: return
	BARA_NET.finish(self, token)

func bara_impact(at: Vector3, explosive: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server(): _net_bara_impact.rpc(at, explosive)
	else: _net_bara_impact(at, explosive)

@rpc("any_peer", "call_local", "reliable")
func _net_bara_impact(at: Vector3, explosive: bool) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() not in [0, 1]: return
	BARA.VFX.impact(_get_skills_container(), at, explosive)

@rpc("any_peer", "call_remote", "reliable")
func _net_bara_rejected(reason: String) -> void:
	if multiplayer.get_remote_sender_id() != 1: return
	BARA_NET.feedback(self, reason)
