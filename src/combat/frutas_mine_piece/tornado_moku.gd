extends CharacterBody3D
## TornadoEntity (Mine Piece v14), modo 0 com a textura slash_white — o tornado do White
## Vine, na AITornadoProcedure: parado no chão, cresce 0,2 × CNT6 por tick até 6 + cnt6 de
## SIZE (1,2 × 1,2 blocos × SIZE); a cada tick fere no meio do corpo (cubo de 1 + largura)
## com 11 × CNT6 e joga para cima (y_knockback = CNT6); some com cnt2 > 80.
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const PASTA := "res://assets/mine_piece/frutas/moku/"

var c
var tamanho := 1.0
var cnt6 := 4.0
var health := 50.0
var _cnt2 := 0
var _tempo := 0.0
var _visual: Node3D
var _funil: Node3D            # funil procedural (anéis girando): a malha do mod sozinha quase não se via (15/11/2026)


func _ready() -> void:
	add_to_group(AlvosDeGolpe.GRUPO)
	add_to_group("tornado_moku_mine_piece")
	set_meta(B.DONO, c.ator.get_instance_id())
	collision_layer = 0
	collision_mask = 0
	var hb := Area3D.new()
	hb.name = "Hurtbox"
	hb.collision_layer = 4
	hb.collision_mask = 0
	add_child(hb)
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	hb.add_child(cs)
	var caminho := PASTA + "mp_tornado.glb"
	if ResourceLoader.exists(caminho):
		_visual = (load(caminho) as PackedScene).instantiate()
		add_child(_visual)
		VfxFrutaMinePiece.render_do_mod(_visual)
		var anim := _visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim != null and anim.get_animation_list().size() > 0:
			anim.play(anim.get_animation_list()[0])
	health *= B.DANO_DA_ARENA_POR_DANO_DO_MOD * PerfilDeFrutas.ESCALA_DO_MOD
	_montar_funil()
	_dimensionar()


## Funil de fumaça: 10 anéis empilhados, mais largos no alto, girando em sentidos alternados. Unidade = o lado do corpo do tornado
## (a escala vem de `_dimensionar`), então cresce junto com ele. Só desenho: o dano é o do `_passo`.
func _montar_funil() -> void:
	_funil = Node3D.new()
	_funil.name = "Funil"
	add_child(_funil)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.97, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = FxUtil.brilho(Color(0.96, 0.97, 1.0, 0.5), 1.4, 0.5)
	for i in 10:
		var f := float(i) / 9.0
		var toro := TorusMesh.new()
		toro.inner_radius = 0.80
		toro.outer_radius = 1.0
		toro.rings = 24
		toro.ring_segments = 5
		var anel := MeshInstance3D.new()
		anel.mesh = toro
		anel.material_override = mat
		anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anel.position = Vector3(0.0, 0.18 + f * 1.45, 0.0)
		var largura := 0.30 + 0.85 * f
		anel.scale = Vector3(largura, 0.55, largura)
		anel.set_meta("vel", randf_range(2.0, 4.5) * (1.0 if i % 2 == 0 else -1.0))
		_funil.add_child(anel)


func _process(delta: float) -> void:
	if _funil == null:
		return
	for anel in _funil.get_children():
		anel.rotation.y += float(anel.get_meta("vel", 2.0)) * delta


func lado_b() -> float:
	return 1.2 * tamanho


func _dimensionar() -> void:
	var cs := get_node("Hurtbox").get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = Vector3.ONE * B.m(lado_b())
	cs.position.y = B.m(lado_b()) * 0.5
	if _visual != null:
		_visual.scale = Vector3.ONE * B.METROS_POR_BLOCO * tamanho
	if _funil != null:
		_funil.scale = Vector3.ONE * B.m(lado_b())


func centro_do_corpo() -> Vector3:
	return global_position + Vector3.UP * B.m(lado_b()) * 0.5


func take_damage(dano: float, _origem := Vector3.ZERO, _empurrao := Vector3.ZERO, _stun := 0.0) -> void:
	if not is_instance_valid(c) or not c.servidor() or int(get_meta("autor_do_dano", 0)) == c.ator.get_instance_id():
		return
	health -= dano


func _physics_process(delta: float) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree() or not is_instance_valid(c.ator) or not c.fruta_ativa():
		queue_free()
		return
	if not c.servidor():
		return
	_tempo += delta
	while _tempo >= B.TICK and not is_queued_for_deletion():
		_tempo -= B.TICK
		_passo()


func _passo() -> void:
	if health <= 0.0:
		queue_free()
		return
	_cnt2 += 1
	var k6 := 1.0 + cnt6 * 0.1
	if tamanho < 6.0 + cnt6:
		tamanho = minf(tamanho + 0.2 * k6, 6.0 + cnt6)
		_dimensionar()
	var a := B.Ataque.new(float(Balance.MINE_PIECE_MOKU.tornado) * k6, 1.0 + lado_b(), 0.5, false)
	a.empurrao_extra = Vector3(0.0, k6, 0.0)
	B.ataque_em_area(c.ator, global_position, centro_do_corpo(), a, c.tick, c.imunidade,
		PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
	# Nuvem girando em volta (4 × altura partículas por tick no mod).
	VfxFrutaMinePiece.particulas(self, PASTA + "particle_big_smoke.png", 12, centro_do_corpo(),
		int(4.0 * lado_b()), Vector3(B.m(lado_b() * 0.5), B.m(lado_b() * 0.5), B.m(lado_b() * 0.5)), 1.0, 0.6, 0.9, 24)
	if _cnt2 % 10 == 0:
		VfxFrutaMinePiece.som(self, "res://assets/mine_piece/frutas/moku/sons/moku_impacto.wav", centro_do_corpo(), 0.5 * B.tamanho(lado_b(), lado_b()))
	if _cnt2 > 80:
		queue_free()
