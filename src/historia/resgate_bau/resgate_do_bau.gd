class_name ResgateDoBau
extends Node
# ============================================================================
#  RESGATE DO BAÚ (21/11/2026) — o ORQUESTRADOR da 3ª missão (regras: `RegrasDoResgateDoBau`). Aceita a missão com o Barba Negra → põe o mímico no mapa e a BÚSSOLA aponta para ele →
#  um golpe o derruba → nasce o drop "Baú misterioso" → o jogador o pega (missão PRONTA) → entrega ao Barba Negra (a janela dele paga 20 moedas + 700 XP).
#  Recarregar o jogo no meio refaz o que falta (mímico se ainda procurando; drop no mesmo lugar se já solto). Só o jogador local vê/joga (estado no progresso dele).
# ============================================================================
const TEMPO_ENTRE_VERIFICACOES := 0.5

var progressao: ProgressaoDoPersonagem
var hud: HistoriaHud
var jogador_de: Callable
const MarcadorDeMissao := preload("res://src/ui/marcador_de_missao.gd")
const MISSAO := "resgate_do_bau"
var mimico: BauMimico
var drop: BauMisteriosoDrop
var _verificar_em := 0.0
var _bussola: Control


func _ready() -> void:
	name = "ResgateDoBau"
	if hud != null:
		_bussola = hud.ligar_bussola_de_missao(progressao, Callable(self, "ponto_da_bussola"), jogador_de, "Baú")


## Para onde a bússola aponta (null = escondida): o mímico enquanto se procura; o drop enquanto está no chão.
func ponto_da_bussola() -> Variant:
	if progressao == null:
		return null
	match RegrasDoResgateDoBau.fase(progressao):
		RegrasDoResgateDoBau.PROCURANDO:
			return mimico.global_position if is_instance_valid(mimico) else _ponto_no_chao(RegrasDoResgateDoBau.PONTO_DO_MIMICO)
		RegrasDoResgateDoBau.SOLTO:
			if is_instance_valid(drop):
				return drop.global_position
			var p: Variant = RegrasDoResgateDoBau.posicao_do_drop(progressao)
			return p
	return null


func _process(delta: float) -> void:
	_verificar_em -= delta
	if _verificar_em > 0.0 or progressao == null:
		return
	_verificar_em = TEMPO_ENTRE_VERIFICACOES
	RegrasDoResgateDoBau.comecar(progressao)             # aceitou a missão com o Barba Negra → começa a procura
	match RegrasDoResgateDoBau.fase(progressao):
		RegrasDoResgateDoBau.PROCURANDO:
			_garantir_mimico()
		RegrasDoResgateDoBau.SOLTO:
			_garantir_drop()


func _ponto_no_chao(base: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(base.x, base.y + 30.0, base.z), Vector3(base.x, base.y - 20.0, base.z))
	var r := get_viewport().world_3d.direct_space_state.intersect_ray(q)
	return (r["position"] as Vector3) if not r.is_empty() else base


func _garantir_mimico() -> void:
	if is_instance_valid(mimico):
		return
	mimico = BauMimico.new()
	mimico.jogador_de = jogador_de
	get_parent().add_child(mimico)
	mimico.global_position = _ponto_no_chao(RegrasDoResgateDoBau.PONTO_DO_MIMICO)
	mimico.fixar_origem()                 # o centro da fuga é ONDE ele nasceu (o `_ready` rodou antes do posicionamento)
	mimico.derrubado.connect(_ao_derrubar)
	MarcadorDeMissao.marcar(mimico, MISSAO, 2.8, true)         # objetivo marcado na tela enquanto se procura o mímico
	mimico.revelado.connect(func() -> void:
		if hud != null: hud.avisar(_fala("mimico_revela", "Mímico: É um mímico! Acerte um ataque nele antes que fuja.")))


func _ao_derrubar(onde: Vector3) -> void:
	MarcadorDeMissao.marcar(mimico, MISSAO, 2.8, false)
	if RegrasDoResgateDoBau.mimico_atingido(progressao, onde):
		_garantir_drop()
		if hud != null:
			hud.avisar(_fala("mimico_atingido", "Mímico: Ai!") + "  ·  Pegue o Baú misterioso!")


func _garantir_drop() -> void:
	if is_instance_valid(drop):
		return
	var p: Variant = RegrasDoResgateDoBau.posicao_do_drop(progressao)
	if not (p is Vector3):
		return
	drop = BauMisteriosoDrop.new()
	drop.jogador_de = jogador_de
	get_parent().add_child(drop)
	drop.global_position = p as Vector3
	drop.pegou.connect(_ao_pegar)
	MarcadorDeMissao.marcar(drop, MISSAO, 1.8, true)           # o baú no chão é o objetivo agora


func _ao_pegar() -> void:
	if RegrasDoResgateDoBau.pegar_drop(progressao):
		MarcadorDeMissao.marcar(drop, MISSAO, 1.8, false)
		if is_instance_valid(drop):
			drop.aceitar()
		if hud != null:
			hud.avisar("Você pegou o Baú misterioso (está na mochila). Leve-o ao Barba Negra.")
	elif is_instance_valid(drop):
		drop.soltar_de_novo()                         # mochila cheia: o drop NÃO some, o jogador esvazia um espaço e tenta de novo
		if hud != null:
			hud.avisar("Mochila cheia! Abra espaço para pegar o Baú misterioso.")


## A 1ª linha do estado em `data/dialogos/bau.json` ("Falante: texto"); `padrao` se faltar.
func _fala(estado: String, padrao: String) -> String:
	var l := DialogosDeNpc.linhas("bau", estado, [])
	return "%s: %s" % [l[0]["falante"], l[0]["texto"]] if not l.is_empty() else padrao
