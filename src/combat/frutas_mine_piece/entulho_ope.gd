extends CharacterBody3D
## AIRubbleProcedure, modo 2: segue o centro enquanto cnt1<=30; lança na mira
## com 9 blocos/tick, atraso 0/2/4/6, arrasto horizontal, gravidade e dano varrido.
## A destruição de blocos vira poeira, como a adaptação já adotada para a Goro.
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
var c
var tecnica
var acao := 0
var escala := 1.0
var deslocamento := Vector3.ZERO
var atraso := 0
var textura := "tex_stone"
var health := 20.0
var lancado := false
var power := Vector3.ZERO
var _tempo := 0.0
var _vida := 0
var _chao := 0
var _preparou := false
var _visual: Node3D

func _ready() -> void:
	add_to_group(AlvosDeGolpe.GRUPO)
	add_to_group("entulho_ope_mine_piece")
	collision_layer = 0
	collision_mask = B.MASCARA_MUNDO
	var forma := BoxShape3D.new()
	forma.size = Vector3.ONE * B.m(1.3 * escala)
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.position.y = forma.size.y * 0.5
	add_child(cs)
	var hb := Area3D.new()
	hb.name = "Hurtbox"
	hb.collision_layer = 4
	hb.collision_mask = 0
	add_child(hb)
	var hit := CollisionShape3D.new()
	hit.shape = forma
	hit.position = cs.position
	hb.add_child(hit)
	var caminho := "res://assets/mine_piece/frutas/ope/mp_%s.glb" % textura
	if ResourceLoader.exists(caminho):
		_visual = (load(caminho) as PackedScene).instantiate()
		add_child(_visual)
		_visual.scale = Vector3.ONE * B.METROS_POR_BLOCO * escala
	health *= B.DANO_DA_ARENA_POR_DANO_DO_MOD * PerfilDeFrutas.ESCALA_DO_MOD

func centro_do_corpo() -> Vector3:
	return global_position + Vector3.UP * B.m(1.3 * escala * 0.5)

func take_damage(dano: float, _origem := Vector3.ZERO, _empurrao := Vector3.ZERO, _stun := 0.0) -> void:
	if not is_instance_valid(c) or not c.servidor() or int(get_meta("autor_do_dano", 0)) == c.ator.get_instance_id():
		return
	health -= dano
	if health <= 0.0:
		_sumir()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(c) or not is_instance_valid(c.ator) or c.acao != acao or not c.fruta_ativa() or c.ator.health <= 0.0:
		queue_free()
		return
	if not c.servidor():
		return
	_tempo += delta
	while _tempo >= B.TICK and not is_queued_for_deletion():
		_tempo -= B.TICK
		_passo()

func _passo() -> void:
	if not _preparou:
		if c.ativo and tecnica.cnt1 <= 30:
			var destino: Vector3 = tecnica.centro + deslocamento
			var diferenca := (destino - global_position) / B.METROS_POR_BLOCO
			power = diferenca.clamp(-Vector3.ONE * 10.0, Vector3.ONE * 10.0) * 0.1
			global_position += power * B.METROS_POR_BLOCO
			return
		_preparou = true
		power = c.olhar() * 9.0
	if not lancado:
		if atraso > 0:
			atraso -= 1
			return
		lancado = true
	_vida += 1
	var r := B.tamanho(2.6 * escala, 0.0)
	var passos := int(power.length() + 1.0)
	var direcao := power.normalized()
	var origem := centro_do_corpo()
	var intervalo := 0.0
	for i in passos:
		var ponto := origem + direcao * B.m(float(i))
		intervalo += 1.0
		if intervalo > 0.0:
			intervalo = -1.5 * r
			var ficha: Dictionary = Balance.MINE_PIECE_OPE
			var ataque := B.Ataque.new(float(ficha.entulho) * maxf(r, float(ficha.tamanho_minimo_dano)),
				3.0 * r, float(ficha.empurrao), false)
			B.ataque_em_area(c.ator, global_position, ponto, ataque, c.tick, c.imunidade,
				PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
		if B.solido(get_world_3d(), ponto, 1.3 * escala, 1.3 * escala):
			break
	var contato := move_and_collide(power * B.METROS_POR_BLOCO)
	if contato != null:
		_chao += 1
		power = power.slide(contato.get_normal())
		if _chao == 1:
			VfxGoroMinePiece.fumaca(self, centro_do_corpo(), 4, B.m(r * 0.5), 0.2 * r)
	else:
		_chao = 0
	# LivingEntity: gravidade 0,08, arrasto Y 0,98; AIRubble aproxima X/Z do
	# x_knockback anterior (metade), resultando em 0,75 antes do arrasto 0,91.
	power.x *= 0.75 * 0.91
	power.z *= 0.75 * 0.91
	power.y = (power.y - 0.08) * 0.98
	if _chao >= 8 or _vida > 200:
		_sumir()

func _sumir() -> void:
	VfxGoroMinePiece.fumaca(self, centro_do_corpo(), 4, B.m(escala * 0.5), 0.2 * escala)
	queue_free()
