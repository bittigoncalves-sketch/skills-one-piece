extends Node
## StoneOpeOpeProcedure (v14): quatro entulhos nos primeiros quatro ticks;
## segurar Z prende cnt1=9, soltar avança a 40 e lança em intervalos de 2 ticks.
## No original ANIMATION_1=-19 é imediatamente sobrescrita por 0 durante a carga.
## Mantém essa ausência de pose; no lançamento ANIMATION_1=-7/ANIMATION_2=0.
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const Entulho := preload("res://src/combat/frutas_mine_piece/entulho_ope.gd")
var c
var cnt1 := 0
var cnt2 := 0
var centro := Vector3.ZERO
var entulhos: Array[Node3D] = []

func iniciar(_numero: int) -> void:
	cnt1 = 0
	cnt2 = 0
	centro = c.pe()

func passo() -> void:
	cnt1 += 1
	cnt2 += 1
	c.recarga = c.recarga_total # MobEffectInstance(COOLDOWN_TIME) renovado a cada tick.
	if cnt1 <= 10:
		if cnt1 >= 9 and c.segurando:
			cnt1 = 9
		if cnt1 <= 4:
			_criar_entulho(cnt1)
		centro = c.pe()
	elif cnt1 <= 45:
		cnt1 = maxi(cnt1, 40)
		if cnt1 == 40:
			c.pose("punch_right")
	else:
		c.terminar()

func _criar_entulho(indice: int) -> void:
	var r := B.tamanho(B.ALTURA_JOGADOR, B.LARGURA_JOGADOR)
	var rumo: Vector3 = c.olhar()
	rumo.y = 0.0
	rumo = rumo.normalized()
	var angulo := deg_to_rad(randf_range(45.0, 90.0)) * (1.0 if indice % 2 == 1 else -1.0)
	var deslocamento := rumo.rotated(Vector3.UP, angulo) * B.m(0.5 * B.LARGURA_JOGADOR + 3.0 * r)
	var onde: Vector3 = c.pe() + deslocamento
	# Busca a superfície vertical local; o mapa Godot não tem a grade de blocos.
	var q := PhysicsRayQueryParameters3D.create(onde + Vector3.UP * B.m(7.0),
		onde - Vector3.UP * B.m(7.0), B.MASCARA_MUNDO, [c.ator.get_rid()])
	var contato: Dictionary = c.ator.get_world_3d().direct_space_state.intersect_ray(q)
	if not contato.is_empty():
		onde = contato.position
	var n := Entulho.new()
	n.c = c
	n.tecnica = self
	n.acao = c.acao
	n.escala = r
	n.deslocamento = Vector3(deslocamento.x, B.m(B.ALTURA_JOGADOR * randf_range(0.5, 1.0)), deslocamento.z)
	n.atraso = (indice - 1) * 2
	n.textura = "tex_stone" if randf() < 0.33 else ("tex_oak_planks" if randf() < 0.5 else "tex_oak_log")
	c.get_tree().current_scene.add_child(n)
	n.global_position = onde - Vector3.UP * B.m(1.3 * r)
	entulhos.append(n)
	for i in range(entulhos.size() - 1, -1, -1):
		if not is_instance_valid(entulhos[i]):
			entulhos.remove_at(i)

func cancelar() -> void:
	for n in entulhos:
		if is_instance_valid(n):
			n.queue_free()
	entulhos.clear()
