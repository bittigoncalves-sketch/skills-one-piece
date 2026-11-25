extends Node
## Extensão autoral da Zushi Zushi (12/11/2026): os 2 poderes do Fujitora que o mod não traz. Pesquisa e fontes: `docs/PESQUISA_FUJITORA_ZUSHI.md`.
##  - K  JIGOKU TABI ("Viagem ao Inferno"): ele embainha a espada e uma força gravitacional enorme achata tudo ao redor — cratera.
##  - L  ABARE HIMATSURI ("Festival Furioso"): levanta a rocha em que pisa, voa por cima do campo e faz chover meteoros atrás de si.
## O mod já cobre Gravito (22), Moko (25), Rubble (27) e Meteor (28); estes dois não repetem nenhum. Entrada e dano rodam no servidor
## (mesmo ciclo de vida da Flor de Buda); a recarga é POR TÉCNICA, no `controlador._recargas`, como as do mod.
const JIGOKU := 1002
const ABARE := 1003
## RUBBLE (V): o `FujitoraRubbleProcedure` do mod traduzido faz as pedras nascerem e seguirem o alvo, mas nenhuma causa dano aqui (as pedras do mod dependem da física
## da entidade `rubble`, que o jogo não tem). Pedido do dono (12/11/2026: "C e V não fazem nada"): o V usa esta versão própria — chuva de rochas sobre o alvo mirado.
## O número é o que o mod oferece para o Rubble na lista (a 4ª técnica da Zushi).
const RUBBLE := 26
const R_CUSTO := 600.0
const R_RECARGA := 12.0
const R_DURACAO := 1.6
const R_ROCHA_A_CADA := 0.08
const R_ALCANCE := 40.0
const R_ESPALHA := 6.0
const R_RAIO_DO_IMPACTO := 2.6
const DADOS := {
	"K": {"numero": JIGOKU, "nome": "Jigoku Tabi", "custo": 450.0, "recarga": 14.0},
	"L": {"numero": ABARE, "nome": "Abare Himatsuri", "custo": 700.0, "recarga": 24.0},
}
const J_PREPARO := 0.7           # embainhar: o corpo para, a cratera vem no fim
const J_DURACAO := 1.4
const J_RAIO := 14.0
const A_DURACAO := 4.0
const A_VELOCIDADE := 13.0
const A_SUBIDA := 2.2            # altura da pedra sobre o chão
const A_METEORO_A_CADA := 0.2
const A_QUEDA := 0.55
const A_RAIO_DO_IMPACTO := 3.5

var controlador: Node
var ativo := false
var poder := 0
var tempo := 0.0
var _feito := false
var _origem := Vector3.ZERO
var _spec: DamageSpec
var _proximo_meteoro := 0.0
var _meteoros: Array = []        # [{no, alvo, t}]
var _altura_base := 0.0


func iniciar(tecla: String) -> bool:
	var ator: Player = controlador.ator
	var d: Dictionary = DADOS[tecla]
	if ativo or controlador.ativo or not controlador.servidor() or not controlador.fruta_ativa() or ator.morrendo or not ator.corpo_livre_para_golpe():
		return false
	if controlador.recarga_da_tecnica(int(d.numero)) > 0.0 or ator.energy + 0.001 < float(d.custo):
		return false
	if int(d.numero) == JIGOKU and not ator.is_on_floor():
		return false                                  # a Viagem ao Inferno é um golpe no chão
	ator.gastar_energia(float(d.custo))
	controlador._sincronizar_para_o_mod()
	ativo = true
	controlador.ativo = true
	controlador.selecao = int(d.numero)
	ator.set_meta(ControladorFrutaMinePiece.META, controlador.get_instance_id())
	controlador.iniciar_recarga(int(d.numero), float(d.recarga))
	poder = int(d.numero)
	tempo = 0.0
	_feito = false
	_origem = ator.global_position
	_altura_base = ator.global_position.y
	_proximo_meteoro = 0.0
	_spec = Balance.novo("zushi_zushi", tecla, ator.escala_de_dano_da_fruta("zushi_zushi"))
	if poder == ABARE:
		var pedra := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = Vector3(3.2, 0.9, 3.2)
		pedra.mesh = caixa
		pedra.material_override = _material(Color(0.36, 0.34, 0.32), 0.0)
		pedra.position = Vector3(0, -1.0, 0)
		ator.add_child(pedra)
		pedra.name = "PedraDoFujitora"
	return true


## Rubble (V): a chuva de rochas cai em volta do ponto mirado (o inimigo mais perto da linha da mira, ou o chão a 18 m).
func iniciar_rubble() -> bool:
	var ator: Player = controlador.ator
	if ativo or controlador.ativo or not controlador.servidor() or not controlador.fruta_ativa() or ator.morrendo or not ator.corpo_livre_para_golpe():
		return false
	if controlador.recarga_da_tecnica(RUBBLE) > 0.0 or ator.energy + 0.001 < R_CUSTO:
		return false
	ator.gastar_energia(R_CUSTO)
	controlador._sincronizar_para_o_mod()
	ativo = true
	controlador.ativo = true
	controlador.selecao = RUBBLE
	ator.set_meta(ControladorFrutaMinePiece.META, controlador.get_instance_id())
	controlador.iniciar_recarga(RUBBLE, R_RECARGA)
	poder = RUBBLE
	tempo = 0.0
	_proximo_meteoro = 0.0
	_altura_base = ator.global_position.y
	_origem = _ponto_mirado(ator)
	_spec = Balance.novo("zushi_zushi", "V", ator.escala_de_dano_da_fruta("zushi_zushi"))
	_anel(_origem, R_ESPALHA)
	_marcador_de_queda(_origem)
	return true


## O alvo da chuva: o inimigo mais perto da linha da mira dentro de R_ALCANCE; sem inimigo, o chão a 18 m na direção da câmera.
func _ponto_mirado(ator: Player) -> Vector3:
	var olho := ator.global_position + Vector3.UP * 1.6
	var rumo: Vector3 = -ator.global_basis.z
	var cam := ator.get_viewport().get_camera_3d()
	if cam != null:
		olho = cam.global_position
		rumo = -cam.global_basis.z
	var melhor: Node = null
	var melhor_d := INF
	for alvo in AlvosDeGolpe.todos(get_tree()):
		if not MundoMinePiece.atacavel(ator, alvo) or CombatResolver.e_fogo_amigo(alvo, ator):
			continue
		var c := AlvosDeGolpe.centro(alvo)
		var t := (c - olho).dot(rumo)
		if t < 0.0 or t > R_ALCANCE:
			continue
		var d := c.distance_to(olho + rumo * t)
		if d < melhor_d and d < 8.0:
			melhor_d = d
			melhor = alvo
	var ponto: Vector3
	if melhor != null:
		ponto = AlvosDeGolpe.centro(melhor)
	else:
		ponto = ator.global_position + Vector3(rumo.x, 0.0, rumo.z).normalized() * 18.0
	ponto.y = ator.global_position.y
	return ponto


func _physics_process(delta: float) -> void:
	_cair_meteoros(delta)
	if not ativo:
		return
	var ator: Player = controlador.ator
	if not is_instance_valid(ator) or not controlador.fruta_ativa() or ator.morrendo:
		cancelar()
		return
	tempo += delta
	if poder == RUBBLE:
		var ator_r: Player = controlador.ator
		ator_r.velocity.x = 0.0                                  # o jogador firma os pés enquanto levanta as rochas
		ator_r.velocity.z = 0.0
		_proximo_meteoro -= delta
		while _proximo_meteoro <= 0.0 and tempo < R_DURACAO:
			_proximo_meteoro += R_ROCHA_A_CADA
			_lancar_rocha()
		if tempo >= R_DURACAO + A_QUEDA:
			cancelar()
		return
	if poder == JIGOKU:
		if not _feito and tempo >= J_PREPARO:
			_feito = true
			_cratera()
		if tempo >= J_DURACAO:
			cancelar()
	else:
		_proximo_meteoro -= delta
		while _proximo_meteoro <= 0.0 and tempo < A_DURACAO - A_QUEDA:
			_proximo_meteoro += A_METEORO_A_CADA
			_lancar_meteoro(ator)
		if tempo >= A_DURACAO:
			cancelar()


## Jigoku Tabi: tudo num raio J_RAIO leva o dano e é esmagado contra o chão (impulso para BAIXO, atordoamento longo).
func _cratera() -> void:
	var ator: Player = controlador.ator
	var centro := _origem
	_anel(centro, J_RAIO)
	for alvo in AlvosDeGolpe.todos(get_tree()):
		if not MundoMinePiece.atacavel(ator, alvo) or CombatResolver.e_fogo_amigo(alvo, ator):
			continue
		var d := AlvosDeGolpe.centro(alvo) - centro
		if Vector2(d.x, d.z).length() > J_RAIO:
			continue
		CombatResolver.aplicar(alvo, _spec.dano, _spec.cast_id, _spec.teto, centro, Vector3(0.0, -14.0, 0.0), 1.0, 0.0, false, null, ator)


func _lancar_meteoro(ator: Player) -> void:
	var rumo: Vector3 = -ator.global_basis.z
	rumo.y = 0.0
	rumo = rumo.normalized()
	var ponto := ator.global_position - rumo * 7.0 + Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
	ponto.y = _altura_base
	var m := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.7
	esfera.height = 1.4
	m.mesh = esfera
	m.material_override = _material(Color(1.0, 0.45, 0.1), 2.0)
	get_tree().current_scene.add_child(m)
	m.global_position = ponto + Vector3.UP * 18.0
	_meteoros.append({"no": m, "alvo": ponto, "t": 0.0})


## Aviso e presença do Rubbles (15/11/2026): medido em 3,0% da imagem — pedras cinza caindo de 18 m sobre um ponto sem marca. Disco pulsante roxo na
## área de queda (raio `R_ESPALHA`) e coluna de luz no centro, durante toda a chuva; some com fade. Só visual.
func _marcador_de_queda(centro: Vector3) -> void:
	var cor := Color(0.7, 0.35, 1.0)
	var raiz := Node3D.new()
	get_tree().current_scene.add_child(raiz)
	raiz.global_position = centro
	var disco := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 1.0
	cil.bottom_radius = 1.0
	cil.height = 0.06
	cil.radial_segments = 40
	disco.mesh = cil
	var mat := FxUtil.mesh_emissive_material(Color(cor.r, cor.g, cor.b, 0.55), 1.8, true)
	disco.material_override = mat
	disco.scale = Vector3(R_ESPALHA, 1.0, R_ESPALHA)
	disco.position.y = 0.08
	raiz.add_child(disco)
	var coluna := MeshInstance3D.new()
	var tubo := CylinderMesh.new()
	tubo.top_radius = 0.5
	tubo.bottom_radius = 1.4
	tubo.height = 22.0
	tubo.radial_segments = 16
	coluna.mesh = tubo
	var mat2 := FxUtil.mesh_emissive_material(Color(cor.r, cor.g, cor.b, 0.32), 1.6, true)
	coluna.material_override = mat2
	coluna.position.y = 11.0
	raiz.add_child(coluna)
	var duracao := R_DURACAO + A_QUEDA
	var tw := raiz.create_tween()
	tw.tween_method(func(t: float) -> void:
		var pulso := 0.75 + 0.25 * sin(t * 18.0)
		mat.albedo_color.a = 0.55 * pulso
		mat2.albedo_color.a = 0.32 * pulso, 0.0, duracao, duracao)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.parallel().tween_property(mat2, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(raiz.queue_free)


func _lancar_rocha() -> void:
	var ponto := _origem + Vector3(randf_range(-R_ESPALHA, R_ESPALHA), 0.0, randf_range(-R_ESPALHA, R_ESPALHA))
	var m := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	var lado := randf_range(0.8, 1.6)
	caixa.size = Vector3(lado, lado, lado)
	m.mesh = caixa
	m.material_override = _material(Color(0.4, 0.38, 0.36).darkened(randf() * 0.25), 0.0)
	(m.material_override as StandardMaterial3D).emission_enabled = true     # veio gravitacional roxo: a rocha lê como a fruta, não como pedra comum
	(m.material_override as StandardMaterial3D).emission = Color(0.55, 0.25, 0.9)
	(m.material_override as StandardMaterial3D).emission_energy_multiplier = 0.7
	get_tree().current_scene.add_child(m)
	m.global_position = ponto + Vector3.UP * 18.0
	m.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	PoderDaFruta.rastro_em_voo(m, "rock", "zushi_zushi")
	_meteoros.append({"no": m, "alvo": ponto, "t": 0.0, "raio": R_RAIO_DO_IMPACTO})


func _cair_meteoros(delta: float) -> void:
	for i in range(_meteoros.size() - 1, -1, -1):
		var m: Dictionary = _meteoros[i]
		m.t += delta
		var no: Node3D = m.no
		if not is_instance_valid(no):
			_meteoros.remove_at(i)
			continue
		no.global_position = (m.alvo as Vector3) + Vector3.UP * lerpf(18.0, 0.0, clampf(m.t / A_QUEDA, 0.0, 1.0))
		if m.t >= A_QUEDA:
			_impacto(m.alvo, float(m.get("raio", A_RAIO_DO_IMPACTO)))
			no.queue_free()
			_meteoros.remove_at(i)
	_soltar_spec()


func _soltar_spec() -> void:
	if not ativo and _meteoros.is_empty() and _spec != null:
		CombatResolver.encerrar(_spec.cast_id)
		_spec = null


func _impacto(ponto: Vector3, raio := A_RAIO_DO_IMPACTO) -> void:
	if _spec == null:
		return
	var ator: Player = controlador.ator if is_instance_valid(controlador) else null
	_anel(ponto, raio)
	VfxFrutaMinePiece.onda_de_choque(self, ponto + Vector3.UP * 0.1, raio * 1.6, Color(0.7, 0.35, 1.0), 0.45)
	VfxGoroMinePiece.clarao(self, ponto + Vector3.UP * 0.8, raio * 0.8, 0.22, Color(0.7, 0.35, 1.0))
	if ator == null:
		return
	for alvo in AlvosDeGolpe.todos(get_tree()):
		if not MundoMinePiece.atacavel(ator, alvo) or CombatResolver.e_fogo_amigo(alvo, ator):
			continue
		if AlvosDeGolpe.distancia_ao_corpo(alvo, ponto) > raio:
			continue
		var d := (AlvosDeGolpe.centro(alvo) - ponto)
		d.y = 0.0
		CombatResolver.aplicar(alvo, _spec.dano, _spec.cast_id, _spec.teto, ponto, d.normalized() * 6.0 + Vector3.UP * 4.0, 0.4, 0.0, false, null, ator)


## Anel que se abre no chão (poeira da cratera / do impacto): curto e barato — um disco que cresce e some.
func _anel(centro: Vector3, raio: float) -> void:
	var disco := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 1.0
	cil.bottom_radius = 1.0
	cil.height = 0.15
	disco.mesh = cil
	var mat := _material(Color(0.25, 0.2, 0.17), 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disco.material_override = mat
	get_tree().current_scene.add_child(disco)
	disco.global_position = centro + Vector3.UP * 0.1
	disco.scale = Vector3(0.3, 1.0, 0.3)
	var tw := disco.create_tween().set_parallel(true)
	tw.tween_property(disco, "scale", Vector3(raio, 1.0, raio), 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(disco.queue_free)


func _material(cor: Color, brilho: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = brilho
	return m


## O controlador chama durante o voo: sobe até a altura da pedra, depois voa reto para onde a câmera olha.
func velocidade(atual: Vector3, q: MoveFrame) -> Vector3:
	if poder == JIGOKU:
		return Vector3(0, minf(atual.y, 0), 0)
	var ator: Player = controlador.ator
	var alvo_y := _altura_base + A_SUBIDA
	var vy := clampf((alvo_y - ator.global_position.y) * 6.0, -6.0, 8.0)
	return Vector3(q.frente.x * A_VELOCIDADE, vy, q.frente.z * A_VELOCIDADE)


func cancelar() -> void:
	var ator: Player = controlador.ator if is_instance_valid(controlador) else null
	if is_instance_valid(ator):
		var pedra := ator.get_node_or_null("PedraDoFujitora")
		if pedra != null:
			pedra.queue_free()
	if ativo and is_instance_valid(controlador):
		controlador.ativo = false
		if is_instance_valid(ator) and int(ator.get_meta(ControladorFrutaMinePiece.META, 0)) == controlador.get_instance_id():
			ator.remove_meta(ControladorFrutaMinePiece.META)
	ativo = false
	_soltar_spec()           # meteoros já lançados ainda caem: `_cair_meteoros` solta o spec quando o último pousar


func _exit_tree() -> void:
	for m in _meteoros:
		if is_instance_valid(m.no):
			m.no.queue_free()
	_meteoros.clear()
	cancelar()


## Estado dos dois poderes para o HUD de técnicas (mesmo formato do `estado_das_tecnicas`).
func estados() -> Array:
	var ator: Player = controlador.ator
	var saida := []
	for tecla: String in DADOS:
		var d: Dictionary = DADOS[tecla]
		saida.append({"nome": d.nome, "tecla": tecla, "selecionada": ativo and poder == int(d.numero), "custo": d.custo,
			"recarga": controlador.recarga_da_tecnica(int(d.numero)), "recarga_total": float(d.recarga),
			"sem_energia": ator.energy + 0.001 < float(d.custo), "bloqueada": ator.max_energy + 0.001 < float(d.custo)})
	return saida
