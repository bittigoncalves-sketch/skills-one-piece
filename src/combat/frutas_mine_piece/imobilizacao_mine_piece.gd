class_name ImobilizacaoMinePiece
extends Node
## Lentidão X + COOLDOWN_TIME/COMBAT/BACK_STEP/FLY nos ALVOS (Mine Piece v14: White Out,
## e outras técnicas que prendem): o corpo não anda, não golpeia, não usa técnica e não
## voa enquanto dura. Reaplicar renova. No jogador vale o `is_frozen` que a locomoção e a
## entrada já respeitam; em NPC/bicho, a física dele pausa (a mesma regra do gelo da Hie).
const NOME := "ImobilizacaoMinePiece"

## Posse por ORIGEM: cada técnica que prende o alvo tem o seu token (nome → segundos que faltam), com expiração própria. O nó é um só por
## alvo e só cai quando NENHUM token resta; quem prendeu só remove o próprio (`liberar_origem`). `origem` vazia = origem anônima/legada.
var _origens := {}
var _parou_fisica := false
var _congelou := false


static func aplicar(alvo: Node, segundos: float, origem: String = "") -> void:
	if alvo == null or not is_instance_valid(alvo) or not alvo.is_inside_tree():
		return
	var atual := alvo.get_node_or_null(NOME) as ImobilizacaoMinePiece
	if atual == null:
		atual = ImobilizacaoMinePiece.new()
		atual.name = NOME
		alvo.add_child(atual)
	atual._origens[origem] = maxf(float(atual._origens.get(origem, 0.0)), segundos)
	StatusFX.aplicar(alvo, StatusFX.PRESO, segundos)


## Solta o alvo AGORA (não no fim do quadro): o golpe final do C precisa que ele possa ser empurrado.
static func liberar(alvo: Node) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return
	var atual := alvo.get_node_or_null(NOME)
	if atual != null:
		alvo.remove_child(atual)      # o `_exit_tree` devolve a física e tira o "preso" na hora
		atual.queue_free()


## Segundos que faltam para a imobilização do alvo acabar, somando todas as origens (o maior token; 0 se não há).
static func restante(alvo: Node) -> float:
	if alvo == null or not is_instance_valid(alvo):
		return 0.0
	var atual := alvo.get_node_or_null(NOME) as ImobilizacaoMinePiece
	var maior := 0.0
	if atual != null:
		for v in atual._origens.values():
			maior = maxf(maior, float(v))
	return maior


## Tira SÓ o token da origem e solta o alvo se não sobrou nenhum: outra técnica que também o prende (antes ou depois) continua valendo.
## Devolve se o alvo foi solto de fato.
static func liberar_origem(alvo: Node, origem: String) -> bool:
	if alvo == null or not is_instance_valid(alvo):
		return false
	var atual := alvo.get_node_or_null(NOME) as ImobilizacaoMinePiece
	if atual == null:
		return false
	atual._origens.erase(origem)
	if atual._origens.is_empty():
		liberar(alvo)
		return true
	return false


static func ativa(alvo: Node) -> bool:
	return alvo != null and is_instance_valid(alvo) and alvo.get_node_or_null(NOME) != null


func _ready() -> void:
	var alvo := get_parent()
	if not bool(alvo.get_meta("is_frozen", false)):
		alvo.set_meta("is_frozen", true)
		_congelou = true
	if alvo is CharacterBody3D:
		(alvo as CharacterBody3D).velocity = Vector3.ZERO
	if not alvo.is_in_group("player") and alvo.is_physics_processing():
		alvo.set_physics_process(false)
		_parou_fisica = true


func _physics_process(delta: float) -> void:
	for origem in _origens.keys():
		_origens[origem] = float(_origens[origem]) - delta
		if float(_origens[origem]) <= 0.0:
			_origens.erase(origem)
	if _origens.is_empty():
		queue_free()


func _exit_tree() -> void:
	var alvo := get_parent()
	if not is_instance_valid(alvo):
		return
	if _congelou:
		alvo.set_meta("is_frozen", false)
	if _parou_fisica:
		alvo.set_physics_process(true)
	StatusFX.remover(alvo, StatusFX.PRESO)
