class_name MunicaoMinePiece
extends CharacterBody3D
## A munição que anda sozinha no Mine Piece v14 — o laço comum da AIEntityBirdProcedure
## (lança e pássaro da Hie) e da AIFistProcedure (punho da Moku, e as cabeças/punhos de
## outras frutas): a cada tick anda `velocidade` blocos na direção em que olha, um bloco
## por passo, ferindo num cubo de 3 × tamanho a cada ~1,5 × tamanho blocos. Para no primeiro
## alvo ou parede e fica ali (cnt1 − 1, cnt2 + 1); some com cnt1 > limite_cnt1 ou cnt2 >
## limite_cnt2. Cada munição configura os números em `_configurar` e o que muda por cima.
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")

var c                       # ControladorFrutaMinePiece do dono
var tamanho := 1.0          # atributo SIZE
var cnt6 := 0.0             # a carga copiada da técnica
var rumo := Vector3.FORWARD # getLookAngle da entidade
var health := 40.0

# ------------------------------------------------- configurados por `_configurar`
var largura_base := 1.0     # EntityType.sized(largura, altura), blocos
var altura_base := 1.0
var velocidade := 4.0       # blocos por tick
var fator_alcance := 1.2    # entity_size = ReturnEntitySize × fator
var dano_base := 15.0       # × CNT6
var empurrao := 0.65        # "knockback"
var fator_extra := 0.5      # x/y/z_knockback = getDeltaMovement × fator × …
var extra_pela_carga := true   # × min(CNT6 × 0,75, 1) (AIEntityBird); AIFist não tem
var mede_do_meio := false   # ataca do meio do corpo (pássaro) ou da base (lança, punho)
var limite_cnt1 := 15
var limite_cnt2 := 10
var modelo := ""            # caminho do .glb importado
var grupo := ""
var brilho := false         # o mod a desenha só pela camada luminosa (RenderType.eyes)

var _cnt1 := 0
var _cnt2 := 0
var _tempo := 0.0
var _visual: Node3D


func _configurar() -> void:
	pass


## O RangeAttack de cada passo. A subclasse pode pôr efeito, guarda, etc.
func _ataque(k6: float, t: float) -> MundoMinePiece.Ataque:
	return B.Ataque.new(dano_base * k6, 3.0 * t, empurrao, false)


## Quando parou (alvo, parede ou morreu): as partículas e o som do mod.
func _impacto(_passo_b: Vector3) -> void:
	pass


## O rastro de partículas que o mod solta a cada passo (ParticleGenerator do de → até).
func _rastro(_de: Vector3, _ate: Vector3) -> void:
	pass


func largura_b() -> float:
	return largura_base * tamanho


func altura_b() -> float:
	return altura_base * tamanho


func _ready() -> void:
	_configurar()
	add_to_group(AlvosDeGolpe.GRUPO)
	if not grupo.is_empty():
		add_to_group(grupo)
	set_meta(B.DONO, c.ator.get_instance_id())
	collision_layer = 0
	collision_mask = 0
	var forma := BoxShape3D.new()
	forma.size = Vector3(B.m(largura_b()), B.m(altura_b()), B.m(largura_b()))
	var hb := Area3D.new()
	hb.name = "Hurtbox"
	hb.collision_layer = 4
	hb.collision_mask = 0
	add_child(hb)
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.position.y = forma.size.y * 0.5
	hb.add_child(cs)
	if not modelo.is_empty() and ResourceLoader.exists(modelo):
		_visual = (load(modelo) as PackedScene).instantiate()
		add_child(_visual)
		if brilho:
			VfxFrutaMinePiece.brilho_do_mod(_visual)
		else:
			VfxFrutaMinePiece.render_do_mod(_visual)
		_visual.scale = Vector3.ONE * B.METROS_POR_BLOCO * tamanho
	health *= B.DANO_DA_ARENA_POR_DANO_DO_MOD * PerfilDeFrutas.ESCALA_DO_MOD
	_orientar()


## Os modelos do mod apontam para −Z (no geo da partisan os dentes ficam em z < 0 e o
## cabo vai até +9): o rumo vira o −Z do visual.
func _orientar() -> void:
	if _visual == null or rumo.length_squared() < 0.0001:
		return
	var z := -rumo.normalized()
	var x := Vector3.UP.cross(z)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT
	x = x.normalized()
	_visual.global_basis = Basis(x, z.cross(x), z).scaled(Vector3.ONE * B.METROS_POR_BLOCO * tamanho)


func centro_do_corpo() -> Vector3:
	return global_position + Vector3.UP * B.m(altura_b()) * 0.5


func take_damage(dano: float, _origem := Vector3.ZERO, _empurrao := Vector3.ZERO, _stun := 0.0) -> void:
	if not is_instance_valid(c) or not c.servidor() or int(get_meta("autor_do_dano", 0)) == c.ator.get_instance_id():
		return
	health -= dano


func _physics_process(delta: float) -> void:
	# A munição do mod vive sozinha: só some sem dono ou se ele trocar de fruta.
	if not is_instance_valid(c) or not c.is_inside_tree() or not is_instance_valid(c.ator) or not c.fruta_ativa():
		queue_free()
		return
	if not c.servidor():
		return
	_tempo += delta * B.FATOR_DE_PROJETIL * TempoLocal.fator_de_disparo(global_position, c.ator)     # vida baixa do jogador: a munição alheia anda devagar
	while _tempo >= B.TICK and not is_queued_for_deletion():
		_tempo -= B.TICK
		_passo()


## O ponto de onde o mod mede: o meio (pássaro) ou a base (lança, punho).
func _ponto() -> Vector3:
	return centro_do_corpo() if mede_do_meio else global_position


func _passo() -> void:
	_cnt1 += 1
	var t := B.tamanho_municao(altura_b(), largura_b()) * fator_alcance
	var k6 := 1.0 + cnt6 * 0.1
	var passo_b := rumo.normalized()     # power / dis: um bloco por passo
	var extra := passo_b * velocidade * fator_extra * (minf(k6 * 0.75, 1.0) if extra_pela_carga else 1.0)
	var parou := false
	var num1 := 0.0
	for i in maxi(int(velocidade), 1):
		num1 += 1.0
		if num1 > 0.0:
			num1 = -1.5 * t + 1.0
			var a := _ataque(k6, t)
			a.empurrao_extra = extra
			B.ataque_em_area(c.ator, global_position, _ponto(), a, c.tick, c.imunidade,
				PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
			if is_queued_for_deletion():
				return
			if B.primeiro_no_cubo(c.ator, _ponto(), a.lado) != null:
				parou = true
				break
		# setPos eixo a eixo; dentro de bloco, volta e para (isInWall).
		var antes := global_position
		global_position += passo_b * B.METROS_POR_BLOCO
		_rastro(antes, global_position)
		if _dentro_de_parede():
			global_position = antes
			parou = true
			break
	if parou or health <= 0.0:
		_impacto(passo_b)
		_cnt1 -= 1
		_cnt2 += 1
	if health <= 0.0 or _cnt1 > limite_cnt1 or _cnt2 > limite_cnt2:
		queue_free()


## isInWall: os olhos da entidade (85% da altura) dentro de um bloco.
func _dentro_de_parede() -> bool:
	var olhos := global_position + Vector3.UP * B.m(altura_b() * 0.85)
	return B.solido(get_world_3d(), olhos - Vector3.UP * B.m(0.05), 0.1, largura_b() * 0.8)
