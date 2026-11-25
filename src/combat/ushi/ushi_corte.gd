class_name UshiCorte
extends Node3D
## CORTE NO AR da Ushi Ushi (X e C), refeito do zero em 21/11/2026 (o do mod era o Rankyaku traduzido: projétil de entidade, 6% de visibilidade).
## Leveza (pedido: "garantir que não lague"): NENHUM Area3D/física — o acerto é medido na `_physics_process` contra a lista de alvos (uma lista
## por quadro, compartilhada entre todos os cortes); 1 MeshInstance3D (malha estática de 2 superfícies, materiais compartilhados); nada é alocado por quadro; no máximo
## `MAX_VIVOS` cortes ao mesmo tempo (o mais antigo some ao passar do teto). Dano só no servidor; o visual roda em todos.

const MAX_VIVOS := 14
const ESPESSURA := 0.75           # tolerância perpendicular à lâmina (m)
static var _vivos: Array[UshiCorte] = []
static var _quadro := -1
static var _alvos: Array[Node] = []
static var _centros := PackedVector3Array()      # centro de cada alvo, calculado UMA vez por quadro e dividido entre todos os cortes

var dono: Node3D
var direcao := Vector3.FORWARD
var velocidade := 34.0
var alcance := 26.0
var largura := 2.6                # envergadura da lâmina (m)
var inclinacao := 0.0             # giro da lâmina em torno do eixo de voo: 0 = em pé (corte vertical), PI/2 = deitada (horizontal)
var spec: DamageSpec
var empurrao := 7.0
var atordoar := 0.25
var com_dano := true              # false nos testes visuais e nos outros peers
var acertos := 0                  # quantos alvos já feriu (teste/HUD)

var _percorrido := 0.0
var _eixo := Vector3.RIGHT        # eixo da lâmina (de uma ponta à outra)
var _feridos := {}
var _malha: MeshInstance3D
var _vida := 0.0


static func criar(pai: Node, de: Vector3, rumo: Vector3, dono_: Node3D, dado: DamageSpec, larg := 2.6, incl := 0.0, vel := 34.0, alc := 26.0) -> UshiCorte:
	var c := UshiCorte.new()
	c.dono = dono_
	c.spec = dado
	c.largura = larg
	c.inclinacao = incl
	c.velocidade = vel
	c.alcance = alc
	c.direcao = rumo.normalized()
	pai.add_child(c)
	c.global_position = de
	c._preparar()
	return c


func _preparar() -> void:
	var frente := direcao
	var lateral := frente.cross(Vector3.UP)
	if lateral.length_squared() < 0.001:
		lateral = Vector3.RIGHT
	lateral = lateral.normalized()
	var cima := lateral.cross(frente).normalized()
	_eixo = (lateral * cos(inclinacao) + cima * sin(inclinacao)).normalized()
	# Base: X = eixo da lâmina, −Z = frente do voo (a malha arqueia para trás), Y = normal da fita.
	var y := (-frente).cross(_eixo).normalized() * -1.0
	var b := Basis(_eixo, y, -frente).orthonormalized()
	global_basis = b
	_malha = MeshInstance3D.new()
	_malha.mesh = UshiMateriais.malha_do_corte()
	_malha.scale = Vector3(largura, largura, largura * 0.9)
	_malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_malha)
	add_to_group("ushi_corte")
	_vivos.append(self)
	while _vivos.size() > MAX_VIVOS:
		var velho: UshiCorte = _vivos.pop_front()
		if is_instance_valid(velho):
			velho.queue_free()


func _physics_process(delta: float) -> void:
	var passo := velocidade * delta
	var de := global_position
	var para := de + direcao * passo
	# O MUNDO PRIMEIRO: o raio cobre o passo inteiro (sem alcance fixo) + a espessura da lâmina; o que está além da parede não é ferido.
	var limite := passo
	var parede := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(de, para + direcao * 0.3, 1))
	var bateu := not parede.is_empty()
	if bateu:
		limite = maxf(0.0, de.distance_to(parede.position))
	global_position = de + direcao * minf(passo, limite)
	_percorrido += passo
	_vida += delta
	# Afina nos últimos 20 % do alcance (some em vez de sumir de repente).
	var resto := 1.0 - clampf((_percorrido / alcance - 0.8) / 0.2, 0.0, 1.0)
	_malha.scale = Vector3(largura * (0.55 + 0.45 * resto), largura * (0.4 + 0.6 * resto), largura * 0.9 * (0.6 + 0.4 * resto))
	if com_dano and spec != null:
		_ferir(minf(passo, limite))
	if bateu or _percorrido >= alcance:
		queue_free()


func _ferir(passo: float) -> void:
	var f := Engine.get_physics_frames()
	if f != _quadro:
		_quadro = f
		_alvos = AlvosDeGolpe.todos(get_tree())
		_centros.resize(_alvos.size())
		for i in _alvos.size():
			var n := _alvos[i]
			_centros[i] = AlvosDeGolpe.centro(n as Node3D) if is_instance_valid(n) and n is Node3D else Vector3(1e9, 1e9, 1e9)
	var meia := largura * 0.5
	var pos := global_position
	var dir := direcao
	var eixo := _eixo
	var tras := -(passo + 1.2)
	for i in _alvos.size():
		var rel := _centros[i] - pos
		var avanco := rel.dot(dir)
		if avanco > 1.2 or avanco < tras:
			continue                                           # só quem a lâmina atravessou neste passo (com folga do corpo): quase todos saem aqui
		var ao_longo := rel.dot(eixo)
		if absf(ao_longo) > meia + 3.0:
			continue                                           # longe demais ao longo da lâmina (folga de 3 m para corpos grandes)
		var alvo := _alvos[i]
		if not is_instance_valid(alvo) or _feridos.has(alvo):
			continue
		if not MundoMinePiece.atacavel(dono, alvo) or CombatResolver.e_fogo_amigo(alvo, dono):
			continue
		var ponto := pos + eixo * clampf(ao_longo, -meia, meia)    # ponto da lâmina mais perto do alvo
		if AlvosDeGolpe.distancia_ao_corpo(alvo, ponto) > ESPESSURA:
			continue
		_feridos[alvo] = true
		acertos += 1
		var rumo := (dir * 0.8 + Vector3.UP * 0.2).normalized()
		CombatResolver.aplicar(alvo, spec.dano, spec.cast_id, spec.teto, pos, rumo * empurrao, atordoar, 0.0, false, null, dono)
		PoderVfx.impacto(dono, ponto, UshiMateriais.COR_DO_CORTE, 1.5, PoderVfx.Forma.CIRCULO)
		UshiAudio.tocar(dono, "impacto_corte", 0, -8.0)


## Remove os cortes de um dono (a fruta saiu do jogador).
static func limpar_do_dono(dono_: Node, arvore: SceneTree) -> void:
	for c in arvore.get_nodes_in_group("ushi_corte"):
		if (c as UshiCorte).dono == dono_:
			c.queue_free()


func _exit_tree() -> void:
	_vivos.erase(self)
