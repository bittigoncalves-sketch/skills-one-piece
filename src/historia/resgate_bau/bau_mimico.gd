class_name BauMimico
extends StaticBody3D
# ============================================================================
#  BAÚ MÍMICO (21/11/2026) — parece um baú comum; quando o jogador chega perto (`RAIO_DA_REVELACAO`) a tampa abre com dentes e língua e ele sai SALTITANDO para longe (sem passar
#  de `RAIO_DA_FUGA` do ponto de origem nem entrar na água). UM ataque certeiro o derruba: ele estoura numa nuvem e solta o drop (`atingido` → sinal `derrubado(onde)`).
#  Entra no grupo `alvo_de_golpe` (os golpes procuram alvos por ele, `AlvosDeGolpe`) e responde a `take_damage` como os outros alvos. Corpo ESTÁTICO com colisão (as `DamageZone` dos golpes acham alvos por `body_entered`, então precisa de um corpo físico); anda movendo a posição.
#  Texturas: as de `res://assets/textures/resgate_bau/` (arte do Codex, 16×16) se existirem; senão cores lisas.
#  GATILHO: mais de um mímico no jogo → mover a fuga para um `ComportamentoDeFuga` reutilizável.
# ============================================================================
signal revelado
signal derrubado(onde: Vector3)

enum Estado { DISFARCADO, REVELADO, DERRUBADO }

const GRUPO := "alvo_de_golpe"          # = `AlvosDeGolpe.GRUPO`
const RAIO_DA_REVELACAO := 5.0
const RAIO_DA_FUGA := 22.0
const VELOCIDADE := 4.2
const TEMPO_DO_SALTO := 0.5
const ALTURA_DO_SALTO := 0.55
const T_ABRIR := 0.28
const T_ENCARAR := 0.9                  # depois de se revelar, encara o jogador (boca aberta) antes de fugir

var estado := Estado.DISFARCADO
var origem := Vector3.ZERO              # ponto de partida (o centro da fuga)
var jogador_de: Callable = Callable()
var health := 1.0                       # os golpes leem `health`/`max_health` de alguns alvos
var max_health := 1.0

var _corpo: Node3D
var _tampa: Node3D
var _boca: Node3D
var _dentes_da_tampa: Array[MeshInstance3D] = []
var _t_abrir := 0.0
var _t_salto := 0.0
var _t_encarar := 0.0
var _dir := Vector3.ZERO
var _chao_y := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GRUPO)
	name = "BauMimico"
	collision_layer = 1                     # dentro da máscara 15 dos golpes
	collision_mask = 0
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(1.0, 0.7, 0.8)
	col.shape = forma
	col.position.y = 0.35
	add_child(col)
	_rng.randomize()
	_montar()
	origem = global_position
	_chao_y = global_position.y


## Chamado depois de posicionar o nó: guarda o ponto de origem da fuga e a altura do chão.
func fixar_origem() -> void:
	origem = global_position
	_chao_y = global_position.y


func centro_do_corpo() -> Vector3:
	return global_position + Vector3(0.0, 0.35, 0.0)


func _material(c: Color, textura := "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	var caminho := "res://assets/textures/resgate_bau/%s.png" % textura
	if not textura.is_empty() and ResourceLoader.exists(caminho):
		m.albedo_texture = load(caminho) as Texture2D
		m.albedo_color = Color.WHITE
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


func _caixa(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	m.mesh = b
	m.material_override = mat
	m.position = pos
	pai.add_child(m)
	return m


func _montar() -> void:
	var madeira := _material(Color(0.52, 0.33, 0.14), "mimico_corpo")
	var ferro := _material(Color(0.25, 0.25, 0.28))
	_corpo = Node3D.new()
	_corpo.name = "Corpo"
	add_child(_corpo)
	_caixa(_corpo, Vector3(0.95, 0.5, 0.7), Vector3(0, 0.25, 0), madeira)                 # a base do baú
	_caixa(_corpo, Vector3(0.97, 0.1, 0.72), Vector3(0, 0.46, 0), ferro)                  # o aro de ferro
	_caixa(_corpo, Vector3(0.14, 0.2, 0.06), Vector3(0, 0.34, -0.36), ferro)              # a fechadura (frente = −Z)
	_tampa = Node3D.new()                                                                # a tampa gira na dobradiça (fundo, em cima)
	_tampa.name = "Tampa"
	_tampa.position = Vector3(0, 0.5, 0.35)
	_corpo.add_child(_tampa)
	_caixa(_tampa, Vector3(0.95, 0.22, 0.7), Vector3(0, 0.11, -0.35), _material(Color(0.6, 0.38, 0.17), "mimico_tampa"))
	_caixa(_tampa, Vector3(0.97, 0.06, 0.72), Vector3(0, 0.04, -0.35), ferro)
	_dentes_da_tampa.clear()
	_boca = Node3D.new()                                                                 # dentes e língua: só aparecem com a tampa aberta
	_boca.name = "Boca"
	_boca.visible = false
	_corpo.add_child(_boca)
	# interior da boca (textura 16×16 do Codex: dentes e língua), por baixo da tampa aberta
	_caixa(_boca, Vector3(0.9, 0.03, 0.64), Vector3(0, 0.505, 0.0), _material(Color(0.13, 0.06, 0.09), "mimico_boca"))
	var dente := _material(Color(0.96, 0.94, 0.86), "mimico_dente")
	for i in 6:
		_caixa(_boca, Vector3(0.1, 0.12, 0.06), Vector3(-0.4 + i * 0.16, 0.56, -0.33), dente)       # fileira de baixo (no aro do corpo)
		_dentes_da_tampa.append(_caixa(_tampa, Vector3(0.1, 0.12, 0.06), Vector3(-0.4 + i * 0.16, -0.05, -0.66), dente))   # fileira de cima: PRESA À TAMPA (sobe com ela)
	_caixa(_boca, Vector3(0.28, 0.06, 0.5), Vector3(0, 0.5, -0.05), _material(Color(0.8, 0.12, 0.2), "mimico_lingua"))   # a língua
	for d in _dentes_da_tampa:
		d.visible = false                                                                # só aparecem com a tampa aberta
	for lado in [-1.0, 1.0]:
		_caixa(_boca, Vector3(0.1, 0.1, 0.04), Vector3(lado * 0.2, 0.66, -0.37), _material(Color(1.0, 0.85, 0.2)))       # olhos amarelos


func _process(delta: float) -> void:
	match estado:
		Estado.DISFARCADO:
			_ver_jogador()
		Estado.REVELADO:
			_t_abrir = minf(_t_abrir + delta / T_ABRIR, 1.0)
			_tampa.rotation.x = deg_to_rad(70.0) * smoothstep(0.0, 1.0, _t_abrir)      # + sobe a frente (−Z) da tampa; com sinal negativo ela DESCIA para dentro do baú
			if _t_encarar > 0.0:
				_t_encarar -= delta
				_encarar_jogador()
			else:
				_fugir(delta)


func _jogador() -> Node3D:
	return jogador_de.call() if jogador_de.is_valid() else null


func _ver_jogador() -> void:
	var j := _jogador()
	if j != null and j.global_position.distance_to(global_position) <= RAIO_DA_REVELACAO:
		revelar()


func revelar() -> void:
	if estado != Estado.DISFARCADO:
		return
	estado = Estado.REVELADO
	_boca.visible = true
	for d in _dentes_da_tampa:
		d.visible = true
	_t_salto = 0.0
	_t_encarar = T_ENCARAR
	revelado.emit()


func _encarar_jogador() -> void:
	var j := _jogador()
	if j != null:
		var v := Vector3(j.global_position.x - global_position.x, 0.0, j.global_position.z - global_position.z)
		if v.length() > 0.1:
			rotation.y = atan2(-v.x, -v.z)          # a frente (e a boca) é −Z


## A fuga: saltos curtos para longe do jogador, ficando dentro do raio da origem e longe da água.
func _fugir(delta: float) -> void:
	var j := _jogador()
	var longe := Vector3.ZERO
	if j != null:
		longe = Vector3(global_position.x - j.global_position.x, 0.0, global_position.z - j.global_position.z)
	if _t_salto <= 0.0:
		_dir = _escolher_direcao(longe)
		_t_salto = TEMPO_DO_SALTO
	_t_salto -= delta
	var k := 1.0 - maxf(_t_salto, 0.0) / TEMPO_DO_SALTO
	var passo := _dir * VELOCIDADE * delta
	var nova := global_position + passo
	var chao := _chao_em(nova)
	if is_nan(chao) or _agua_em(nova, chao):
		_t_salto = 0.0                       # sem chão seco à frente: escolhe outra direção no próximo salto
		return
	global_position = Vector3(nova.x, chao + sin(k * PI) * ALTURA_DO_SALTO, nova.z)
	_chao_y = chao
	if _dir.length() > 0.1:
		rotation.y = atan2(-_dir.x, -_dir.z)


func _escolher_direcao(longe: Vector3) -> Vector3:
	var base := longe.normalized() if longe.length() > 0.1 else Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	for tentativa in 8:                      # tenta o rumo "para longe" e, se for ruim, gira
		var ang := deg_to_rad(float(tentativa) * 45.0 * (1.0 if tentativa % 2 == 0 else -1.0)) * 0.5
		var d := base.rotated(Vector3.UP, ang)
		var alvo := global_position + d * 2.5
		var chao := _chao_em(alvo)
		if not is_nan(chao) and not _agua_em(alvo, chao) and alvo.distance_to(origem) <= RAIO_DA_FUGA and absf(chao - _chao_y) < 1.2:
			return d
	return Vector3.ZERO if global_position.distance_to(origem) <= RAIO_DA_FUGA else (origem - global_position).normalized()


func _chao_em(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 4.0, p.z), Vector3(p.x, p.y - 8.0, p.z))
	q.exclude = [get_rid()]                 # sem isto o raio acha o PRÓPRIO corpo e ele "sobe" a cada quadro
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return float((r["position"] as Vector3).y) if not r.is_empty() else NAN


func _agua_em(p: Vector3, chao: float) -> bool:
	var nivel: float = AguaDoMundo.nivel_em(p.x, p.z)
	return not is_nan(nivel) and nivel > chao - 0.25


## Chamado pelos golpes. Qualquer dano positivo derruba (UM ataque certeiro, pedido do dono). Devolve nada; o efeito é o sinal.
func take_damage(amount: float, _origem := Vector3.ZERO, _empurrao := Vector3.ZERO, _stun := 0.0) -> void:
	if estado == Estado.DERRUBADO or amount <= 0.0:
		return
	estado = Estado.DERRUBADO
	health = 0.0
	remove_from_group(GRUPO)
	var onde := global_position
	derrubado.emit(onde)
	_estourar()


func _estourar() -> void:
	# nuvem de lascas e some (as caixas voam em volta e encolhem)
	var t := create_tween().set_parallel(true)
	for filho in _corpo.get_children():
		if filho is Node3D:
			var alvo := (filho as Node3D).position + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.5, 1.6), _rng.randf_range(-1, 1))
			t.tween_property(filho, "position", alvo, 0.35)
			t.tween_property(filho, "scale", Vector3.ONE * 0.05, 0.35)
	t.chain().tween_callback(queue_free)
