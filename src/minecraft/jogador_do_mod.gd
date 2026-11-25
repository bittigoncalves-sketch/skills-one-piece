class_name JogadorDoMod
extends Node
## O JOGADOR visto pelo mod (filho do `Player`): liga as CONQUISTAS do Mine Piece ao jogo.
##   • o estado das conquistas é o `conquistas_mod` da progressão (salvo junto, mesma referência);
##   • as conquistas por `tick` (raízes) são concedidas ao ligar;
##   • a RECOMPENSA do jogo (`recompensa_total`) vira o `PlayerBounty` do mod e, quando muda, roda o `UpdateBountyProcedure`
##     do mod — é ele quem concede as GRADES (30 mil, 100 mil … 3 milhões), e as grades concedem as habilidades.
## `PlayerLevel` é posto no valor que o próprio `UpdateBounty` vai calcular (cópia da conta, abaixo) para a procedure NÃO
## achar que o nível mudou e rodar `WhenRespawn` (cura e reescreve os atributos que o jogo já controla).
## Mensagens "ganhou/perdeu recompensa" do mod saem pelo HUD (`displayClientMessage`).

const INTERVALO := 0.25

var prog: ProgressaoDoPersonagem
var _ent: McEntidade
var _v
var _acumulado := 0.0
var _primeira := true


## Põe (ou religa) o nó no jogador com a progressão `p`.
static func ligar(jogador: Node, p: ProgressaoDoPersonagem) -> JogadorDoMod:
	var n := jogador.get_node_or_null("JogadorDoMod") as JogadorDoMod
	if n == null:
		n = JogadorDoMod.new()
		n.name = "JogadorDoMod"
		jogador.add_child(n)
	n.religar(p)
	return n


## Inventário → camada Minecraft: o que está na hotbar selecionada, na mão secundária e nos slots de armadura passa a ser o equipamento (`setItemSlot`)
## que as procedures do mod leem (`getMainHandItem`, armadura…). Só EMPURRA mudanças: slot vazio que nós nunca preenchemos não apaga o que o mod pôs
## (ex.: o conjunto da Uta Uta). 10/11/2026.
const ESPACOS_DO_INVENTARIO := [[&"MAINHAND", -1], [&"OFFHAND", InventarioMinecraft.MAO_SECUNDARIA], [&"HEAD", InventarioMinecraft.ARMADURA_INI],
	[&"CHEST", InventarioMinecraft.ARMADURA_INI + 1], [&"LEGS", InventarioMinecraft.ARMADURA_INI + 2], [&"FEET", InventarioMinecraft.ARMADURA_INI + 3]]
var _empurrado := {}


func sincronizar_equipamento() -> void:
	if prog == null or _ent == null or not _ent.valida():
		return
	var inv := prog.inventario
	for par in ESPACOS_DO_INVENTARIO:
		var espaco: StringName = par[0]
		var i: int = InventarioMinecraft.HOTBAR_INI + inv.selecionado if int(par[1]) < 0 else int(par[1])
		var p: McItem.Pilha = inv.pilha(i)
		var id := InventarioMinecraft.id_de(p)
		if id == str(_empurrado.get(espaco, "")):
			continue
		if id != "" or str(_empurrado.get(espaco, "")) != "":
			_ent.setItemSlot(espaco, p.copy() if id != "" else McItem.pilha(null, 0))
		_empurrado[espaco] = id


func religar(p: ProgressaoDoPersonagem) -> void:
	if prog != null and prog.inventario.mudou.is_connected(sincronizar_equipamento):
		prog.inventario.mudou.disconnect(sincronizar_equipamento)
	prog = p
	prog.inventario.mudou.connect(sincronizar_equipamento)
	var jogador := get_parent()
	jogador.set_meta("conquistas_do_mod", p.conquistas_mod)
	_ent = McEntidade.de(jogador)
	_ent.religar_conquistas()
	_v = _ent.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null)
	_v.PlayerBountyOld = -1.0                       # 1ª passada: concede as grades que a recompensa já merece, sem mensagem
	_primeira = true
	_ent.conquistas_do_jogador().conceder_as_de_tick()


func _physics_process(delta: float) -> void:
	_acumulado += delta
	if _acumulado < INTERVALO or prog == null or _v == null or not _ent.valida():
		return
	_acumulado = 0.0
	var recompensa := float(prog.recompensa_total())
	_v.PlayerBounty = recompensa
	_v.PlayerLevel = nivel_do_mod(recompensa)
	if recompensa != float(_v.PlayerBountyOld):
		Mc.proc(&"UpdateBountyProcedure").execute(_ent.level(), _ent)
	_primeira = false


## DANO RECEBIDO PELO JOGADOR (09/11/2026, item 4 da auditoria): antes só os personagens do mod (`IaDoMod`) passavam pelos eventos do Forge; o jogador
## apanhava "cru" e a guarda, a resistência e o Haki de Armamento do mod (handlers `WhenEntityTakesDamage`, `RatioDamage`…) nunca o protegiam. Mesma ordem do
## Minecraft: LivingAttack (cancelável) e LivingHurt ANTES; devolve o dano (< 0 = cancelado). `dano_final` dispara o LivingDamage DEPOIS.
## Reentrada: os handlers ferem de dentro do evento (`hurt` → `take_damage` → eventos…); a chamada aninhada passa direto, como a guarda `forge:combat` do mod.
var _em_evento := false
var _fonte_do_golpe: McFonteDeDano


func ao_receber_dano(quantidade: float, de_quem: Node3D) -> float:
	if _em_evento or _ent == null or not _ent.valida():
		return quantidade
	_em_evento = true
	_fonte_do_golpe = _fonte(de_quem)
	var q := quantidade
	for tipo in [&"LivingAttackEvent", &"LivingHurtEvent"]:
		var e := McEvento.disparar(tipo, _ent, _fonte_do_golpe, q)
		if e.cancelado:
			_em_evento = false
			return -1.0
		q = e.quantidade
	_em_evento = false
	return q


## Quanto o dano final de uma criatura do mod é multiplicado ao chegar no jogador (ver `dano_final`).
const ESCALA_DO_GOLPE_DE_MOB := 3.0   # 10/11/2026: 3,0 RESTAURADO às 20:17 (o "voltar o dano" das 16:27 foi lido ao contrário: o dono queria o dano ALTO de volta; com 1,0 o golpe de raid tirava ~6 %)


func dano_final(quantidade: float) -> float:
	if _ent == null or not _ent.valida():
		return quantidade
	var q := quantidade
	# Chamada ANINHADA (`_em_evento`): é a reaplicação de dano que o handler do mod faz DENTRO do evento do golpe original — o dano que de fato
	# chega à vida. Só a chamada de fora dispara o LivingDamageEvent; as duas escalam (a de dentro é a que importa).
	if not _em_evento:
		_em_evento = true
		var e := McEvento.disparar(&"LivingDamageEvent", _ent, _fonte_do_golpe, quantidade)
		_em_evento = false
		if e.cancelado:
			return 0.0
		q = e.quantidade
	# Golpe de uma criatura do mod: o pipeline do mod reaplica ~0,4–3 de dano (medido contra 32 de vida: ~4 % por golpe), pequeno demais para
	# a luta da história. ×`ESCALA_DO_GOLPE_DE_MOB` (10/11/2026, pedido do dono). Queda, fome, afogamento etc. (sem atacante) NÃO escalam.
	var atq = _fonte_do_golpe.atacante if _fonte_do_golpe != null else null
	if atq != null and atq.valida() and not atq.no.is_in_group("player"):
		q *= ESCALA_DO_GOLPE_DE_MOB
		if atq.no.has_meta("fator_dano_nivel"):
			q *= float(atq.no.get_meta("fator_dano_nivel"))          # `NivelDosInimigos`: inimigo de nível alto bate mais forte
	return q


func _fonte(de_quem: Node3D) -> McFonteDeDano:
	var jogador := get_parent()
	var verdadeira: Variant = jogador.get_meta("fonte_mc") if jogador.has_meta("fonte_mc") else null
	if verdadeira is McFonteDeDano:
		return verdadeira
	var atacante := McEntidade.de(de_quem) if de_quem != null and is_instance_valid(de_quem) else null
	return McFonteDeDano.de(&"minecraft:mob_attack" if atacante != null else &"minecraft:generic", atacante)


## O nível que o `UpdateBountyProcedure` calcula a partir da recompensa (cópia da conta, para pré-igualar `PlayerLevel`).
static func nivel_do_mod(b: float) -> float:
	if b >= 1000000.0:
		return roundf(20.0 + (b - 1000000.0) / 400000.0)
	if b >= 100000.0:
		return roundf(10.0 + (b - 100000.0) / 90000.0)
	if b >= 10000.0:
		return roundf(5.0 + (b - 10000.0) / 18000.0)
	return roundf(5.0 * (b / 10000.0))
