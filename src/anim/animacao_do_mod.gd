class_name AnimacaoDoMod
extends Node
## Toca no CORPO DO JOGADOR os clipes de animação do mod (PlayerAnimator → `PoseDoMod`). Filho do dono; publica o
## meta `pose_do_mod` ({papel: Vector3}) que o `ProceduralAnimator` soma aos deslocamentos de cada quadro — o
## mesmo caminho de `pose_de_skill`, então vale nos rigs voxel e skinnado.
##
## Semântica do pacote `MinepieceModAnimationMessage(clipe, alvo, override)` do mod:
##   override = verdadeiro → troca a animação ativa; falso → só toca se nenhuma estiver ativa.
## Depois do último quadro o corpo volta à locomoção (sem `hold_on_last_frame`). Entrada e saída têm uma rampa curta
## (o PlayerAnimator corta seco; a rampa só esconde o salto entre a pose e a locomoção).

const RAMPA_ENTRADA := 0.05
const RAMPA_SAIDA := 0.12
const META := "pose_do_mod"
const META_POSICAO := "posicoes_do_mod"

var clipe := ""
var ultimo := ""        # último clipe que começou (diagnóstico e testes)
var historico: Array[String] = []
var tempo := 0.0
var peso := 0.0
var _saindo := false


## Cria (ou acha) o nó no corpo e toca. Usado pela camada Minecraft quando o mod manda o pacote.
static func no_de(corpo: Node) -> AnimacaoDoMod:
	var n := corpo.get_node_or_null("AnimacaoDoMod") as AnimacaoDoMod
	if n == null:
		n = AnimacaoDoMod.new()
		n.name = "AnimacaoDoMod"
		corpo.add_child(n)
	return n


func ativa() -> bool:
	return not clipe.is_empty() and not _saindo


func tocar(nome: String, sobrescrever: bool) -> bool:
	if ativa() and not sobrescrever:
		return false
	if not PoseDoMod.tem(nome):
		return false
	clipe = nome
	ultimo = nome
	historico.append(nome)
	tempo = 0.0
	_saindo = false
	return true


func parar() -> void:
	if not clipe.is_empty():
		_saindo = true


func _physics_process(delta: float) -> void:
	var dono := get_parent()
	if dono == null:
		return
	if clipe.is_empty():
		_limpar(dono)
		return
	tempo += delta
	if not _saindo and tempo >= PoseDoMod.duracao(clipe) and not PoseDoMod.segura(clipe):
		_saindo = true
	if _saindo:
		peso = maxf(0.0, peso - delta / RAMPA_SAIDA)
		if peso <= 0.0:
			clipe = ""
			_limpar(dono)
			return
	else:
		peso = minf(1.0, peso + delta / RAMPA_ENTRADA)
	var pose := PoseDoMod.amostrar(clipe, minf(tempo, PoseDoMod.duracao(clipe)))
	for papel in pose:
		pose[papel] = (pose[papel] as Vector3) * peso
	dono.set_meta(META, pose)
	var posicoes := PoseDoMod.amostrar_posicoes(clipe, minf(tempo, PoseDoMod.duracao(clipe)))
	for papel in posicoes:
		posicoes[papel] = (posicoes[papel] as Vector3) * peso
	dono.set_meta(META_POSICAO, posicoes)


func _limpar(dono: Node) -> void:
	for chave in [META, META_POSICAO]:
		if dono.has_meta(chave):
			dono.remove_meta(chave)
