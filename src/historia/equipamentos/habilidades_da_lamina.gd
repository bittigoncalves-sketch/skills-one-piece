class_name HabilidadesDaLamina
extends Node
## Z e X das LÂMINAS DE MADEIRA do Epic Fight (21/11/2026, pedido do dono). Filho da `EspadaDaHistoria`; só age com uma lâmina EF de um material da tabela
## `MATERIAIS_COM_HABILIDADE` (hoje só "wooden") na mão. Quem aperta a tecla é a `HistoriaHud`.
##
##  Z — CORTE: um corte de cima para baixo mais pesado que o do clique (dano ×`BONUS_DO_CORTE`), com o golpe `DE_CIMA` do estilo da arma.
##  X — MEIA-LUA: um corte lateral e, quando a lâmina entra na fase ATIVA, solta uma meia-lua (`CorteHorizontal`, em tons de madeira) que atravessa os inimigos à frente.
##      Alterna esquerda/direita, como o X do machado.
##
## DECISÃO (dono, 21/11/2026): "todas as lâminas EF de madeira". GATILHO para estender a pedra/ferro/…: acrescentar o material em `MATERIAIS_COM_HABILIDADE` (o dano da meia-lua já
## escala pelo multiplicador da arma). Custos/recargas são números do corpo da história (energia 100 por nível); playtest pode mexer.

const MATERIAIS_COM_HABILIDADE: Array[String] = ["wooden"]
const CUSTO := {"Z": 15.0, "X": 25.0}
const RECARGA := {"Z": 2.5, "X": 4.0}
const NOMES := {"Z": "Corte", "X": "Meia-lua"}
const BONUS_DO_CORTE := 1.4
## Dano-base da meia-lua lançada (× multiplicador da arma, preso entre 0,6 e 1,6) e o tema de madeira.
const DANO_DA_LUA := 18.0
const COR_DA_LUA := Color(0.93, 0.78, 0.5)
const COR_EMISSIVA_DA_LUA := Color(0.75, 0.5, 0.2)

var recarga := {"Z": 0.0, "X": 0.0}

var _arma: Node
var _jogador: Node3D
var _ex: ExecutorCorpoACorpo
var _acao_z := -1
var _acao_x := -1
var _contragolpe := false
var _ligou := false


func _ready() -> void:
	_arma = get_parent()
	_jogador = _arma.get_parent() as Node3D
	_ex = _jogador.get("combate_direcional")


## A lâmina na mão tem Z/X? (EF, material da tabela, espada ativa.)
func disponivel() -> bool:
	if _arma == null or not bool(_arma.get("ativa")) or str(_arma.get("lamina_ef")) == "":
		return false
	var d := LaminasEpicFight.dados(str(_arma.get("lamina_ef")))
	return not d.is_empty() and str(d.get("material", "")) in MATERIAIS_COM_HABILIDADE


func estado_da_tecla(slot: String) -> Dictionary:
	var custo: float = CUSTO[slot]
	return {"recarga": float(recarga[slot]), "recarga_total": float(RECARGA[slot]), "custo": custo,
		"bloqueada": float(_jogador.max_energy) + 0.001 < custo,
		"sem_energia": float(_jogador.energy) + 0.001 < custo}


func pode_agir() -> bool:
	if not disponivel() or not is_instance_valid(_ex) or _ex.ator == null:
		return false
	if not _jogador.corpo_livre_para_golpe() or not _ex.ator.pode_iniciar():
		return false
	return _ex.estado in [ExecutorCorpoACorpo.Estado.NEUTRO, ExecutorCorpoACorpo.Estado.GUARDA,
		ExecutorCorpoACorpo.Estado.BAIXANDO] and float(_ex.get("_t_recuperacao_pendente")) <= 0.0


func _liberada(slot: String) -> bool:
	return float(recarga[slot]) <= 0.0 and float(_jogador.energy) + 0.001 >= float(CUSTO[slot])


## Tecla Z. true se o corte começou.
func cortar() -> bool:
	if not pode_agir() or not _liberada("Z"):
		return false
	if not _ex.pedir_ataque(GolpeDirecional.Direcao.DE_CIMA) or _ex.estado != ExecutorCorpoACorpo.Estado.PREPARO:
		return false                                   # ficou no buffer ou foi recusado: não cobra nada
	_jogador.gastar_energia(float(CUSTO["Z"]))
	recarga["Z"] = float(RECARGA["Z"])
	_acao_z = _ex.id_acao
	_ex.multiplicador_de_dano *= BONUS_DO_CORTE
	_ligar()
	return true


## Tecla X. true se o corte lateral (que solta a meia-lua) começou.
func lancar_meia_lua() -> bool:
	if not pode_agir() or not _liberada("X"):
		return false
	var direcao := GolpeDirecional.Direcao.PARA_ESQUERDA if not _contragolpe else GolpeDirecional.Direcao.PARA_DIREITA
	if not _ex.pedir_ataque(direcao) or _ex.estado != ExecutorCorpoACorpo.Estado.PREPARO:
		return false
	_jogador.gastar_energia(float(CUSTO["X"]))
	recarga["X"] = float(RECARGA["X"])
	_acao_x = _ex.id_acao
	_contragolpe = not _contragolpe
	_ligar()
	return true


func _ligar() -> void:
	if _ligou:
		return
	_ligou = true
	_ex.fase_mudou.connect(_ao_mudar_fase)
	_ex.golpe_encerrado.connect(_ao_encerrar)


func _ao_mudar_fase(id_acao: int, fase: GolpeDirecional.Fase) -> void:
	if id_acao != _acao_x or fase != GolpeDirecional.Fase.ATIVO:
		return
	_acao_x = -1
	var frente: Vector3 = _ex.ator.base_do_corpo() * Vector3.FORWARD
	var origem := _jogador.global_position + Vector3.UP * 0.3 + frente * 0.9
	var mult := clampf(float(LaminasEpicFight.dados(str(_arma.get("lamina_ef"))).get("multiplicador", 1.0)), 0.6, 1.6)
	CorteHorizontal.criar(_jogador, origem, frente, DANO_DA_LUA * mult, COR_DA_LUA, COR_EMISSIVA_DA_LUA)
	_ex.ator.tremer_camera(0.1)


## O corte pesado acabou (qualquer motivo): devolve o multiplicador. Uma ação só por vez, então desfazer por id basta.
func _ao_encerrar(id_acao: int, _motivo: StringName) -> void:
	if id_acao == _acao_z:
		_acao_z = -1
		_ex.multiplicador_de_dano /= BONUS_DO_CORTE
	elif id_acao == _acao_x:
		_acao_x = -1


## A lâmina saiu da mão no meio de um corte: solta o que ficou pendente.
func abortar() -> void:
	if _acao_z >= 0 and is_instance_valid(_ex):
		_ex.multiplicador_de_dano /= BONUS_DO_CORTE
	_acao_z = -1
	_acao_x = -1


func _physics_process(delta: float) -> void:
	for slot in recarga:
		recarga[slot] = maxf(0.0, float(recarga[slot]) - delta * Lentidao.fator(_jogador))
