class_name FrutaNoChao
extends Area3D
# ============================================================================
#  FRUTA NO CHÃO — a fruta que caiu da árvore e virou item (01/10/2026).
#
#  Cai do galho com gravidade, quica uma vez e fica girando devagar no chão (para ser
#  vista de longe). Decisão do dono: o jogador a recolhe PASSANDO POR CIMA — quem avisa
#  é o sinal `coletada`; somar no inventário é do `ModoHistoria`.
# ============================================================================

signal coletada(fruta: FrutaNoChao)

const GRAVIDADE := 18.0
const RAIO := 0.9                  # alcance da coleta (o corpo do jogador encosta)
const GIRO := 1.1                  # rad/s, parada no chão

var fruta_id := ""
var nascida_em := 0.0              # para descartar a mais antiga quando passar do teto
var no_chao := false

var _visual: Node3D
var _chao_y := 0.0
var _vy := 0.0
var _quicou := false
var _tempo := 0.0
var _pegou := false


## `visual` já é a fruta montada (o pomar reaproveita a do galho). `chao_y`: onde para.
func preparar(id: String, visual: Node3D, chao_y: float, agora: float) -> void:
	fruta_id = id
	nascida_em = agora
	_chao_y = chao_y
	name = "FrutaNoChao_" + id
	collision_layer = 0
	collision_mask = 1               # o jogador (CharacterBody3D) está na camada 1
	monitorable = false
	var forma := SphereShape3D.new()
	forma.radius = RAIO
	var cs := CollisionShape3D.new()
	cs.shape = forma
	add_child(cs)
	_visual = visual
	add_child(_visual)
	body_entered.connect(_ao_encostar)


func _physics_process(delta: float) -> void:
	_tempo += delta
	if not no_chao:
		_vy -= GRAVIDADE * delta
		global_position.y += _vy * delta
		if global_position.y <= _chao_y:
			global_position.y = _chao_y
			if not _quicou and absf(_vy) > 2.0:
				_quicou = true
				_vy = -_vy * 0.3          # um quique só
			else:
				no_chao = true
				_tempo = 0.0
	else:
		_visual.rotation.y += GIRO * delta
		_visual.position.y = 0.05 + sin(_tempo * 2.4) * 0.03
	# A área pode estar encostada no jogador desde que caiu (ele parado embaixo).
	if not _pegou and no_chao:
		for b in get_overlapping_bodies():
			_ao_encostar(b)


func _ao_encostar(corpo: Node) -> void:
	if _pegou or not corpo.is_in_group("player") or not corpo.is_multiplayer_authority():
		return
	_pegou = true
	coletada.emit(self)
	queue_free()
