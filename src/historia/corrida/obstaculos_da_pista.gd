extends Node3D
# ============================================================================
#  OBSTÁCULOS DA PISTA — o que se mexe na corrida de caranguejos (06/10/2026).
#
#  Toras rolando, martelos balançando, braços girando, paredes deslizando e plataformas
#  sobre o mar. Tudo anda pelo RELÓGIO DA CORRIDA (`tempo`, somado pela física; regra
#  do projeto: nada de `SceneTreeTimer` para regra de jogo), então a mesma corrida se
#  repete igual num teste.
#
#  O acerto é CONTA GEOMÉTRICA (distância ao tronco, à cabeça do martelo, ao braço, à
#  parede), não `Area3D`: o caranguejo é camada 0 (pet não bloqueia o dono) e nenhuma
#  área o enxergaria. Paredes, postes e plataformas também são CORPO físico (camada 1):
#  o caranguejo bate, e na plataforma ele é carregado.
#
#  Os dados vêm de `PistaDosCaranguejos.gerar()`, em coordenadas da pista: este nó fica
#  na origem da pista. `impacto` e `zona` recebem posições LOCAIS.
# ============================================================================

const RAIO_DO_CORREDOR := 0.86
const ALTURA_DO_CORREDOR := 0.6         # centro do corpo acima do pé
## Depois de uma batida, o mesmo corredor fica imune por este tempo: com 0,8 s o braço
## giratório pegava o caranguejo ainda atordoado e o prendia na curva (medido).
const INTERVALO_ENTRE_ACERTOS := 1.2

const COR_TORA := Color("8a5a32")
const COR_TORA_PONTA := Color("d9b07a")
const COR_METAL := Color("3d4652")
const COR_PERIGO := Color("f2c230")
const COR_PERIGO_2 := Color("1d1d1d")
const COR_PAREDE := Color("d6453b")
const COR_PAREDE_2 := Color("f2efe8")
const COR_PLATAFORMA := Color("b98c58")

var tempo := 0.0
var _itens: Array[Dictionary] = []
var _zonas: Array = []
var _ultimo_acerto := {}                 # id do corredor -> tempo do último acerto


func montar(obstaculos: Array, zonas: Array) -> void:
	_zonas = zonas
	for o: Dictionary in obstaculos:
		var item := o.duplicate()
		match str(o.tipo):
			"tora": item.no = _tora(o)
			"martelo": item.no = _martelo(o)
			"braco": item.no = _braco(o)
			"parede": item.merge(_parede(o))
			"plataforma": item.no = _plataforma(o)
		_itens.append(item)
	atualizar(0.0)


## Anda o relógio e põe cada obstáculo no lugar dele neste instante.
func atualizar(delta: float) -> void:
	tempo += delta
	for it in _itens:
		match str(it.tipo):
			"tora":
				var x := _onda(it) * float(it.amplitude)
				(it.no as Node3D).position = it.p + (it.direita as Vector3) * x
				# Rola: gira em volta do próprio eixo (a frente da pista) conforme anda de lado.
				(it.no as Node3D).basis = _base_eixo(it.frente).rotated(it.frente, -x / float(it.raio))
			"martelo":
				(it.no as Node3D).basis = Basis(it.frente, _onda(it) * float(it.amplitude)) * _base_lateral(it)
			"braco":
				(it.no as Node3D).basis = _base_lateral(it).rotated(Vector3.UP, tempo * float(it.velocidade) + float(it.fase))
			"parede":
				_mover_parede(it)
			"plataforma":
				(it.no as Node3D).position = it.p + (it.direita as Vector3) * _onda(it) * float(it.amplitude)


## Seno do obstáculo (−1..1) no relógio atual.
func _onda(it: Dictionary) -> float:
	return sin(TAU * tempo / float(it.periodo) + float(it.fase))


## Onde o TOPO da plataforma `i` estará daqui a `adiante` segundos (local): a IA mira o
## pulo onde ela vai estar quando ele cair, não onde ela está.
func posicao_da_plataforma(i: int, adiante := 0.0) -> Vector3:
	var it: Dictionary = _itens[i]
	var onda := sin(TAU * (tempo + adiante) / float(it.periodo) + float(it.fase))
	return it.p + (it.direita as Vector3) * onda * float(it.amplitude) + Vector3.UP * float((it.tamanho as Vector3).y) * 0.5


## Batida num obstáculo neste quadro: {impulso, atordoar} ou {} (nada, ou ainda no
## intervalo do último acerto deste corredor). `pe` = pé do corredor, local.
func impacto(id: int, pe: Vector3) -> Dictionary:
	if tempo - float(_ultimo_acerto.get(id, -10.0)) < INTERVALO_ENTRE_ACERTOS:
		return {}
	var c := pe + Vector3.UP * ALTURA_DO_CORREDOR
	for it in _itens:
		var r := {}
		match str(it.tipo):
			"tora": r = _acerto_tora(it, c)
			"martelo": r = _acerto_martelo(it, c)
			"braco": r = _acerto_braco(it, c)
			"parede": r = _acerto_parede(it, c)
		if not r.is_empty():
			_ultimo_acerto[id] = tempo
			return r
	return {}


## Zonas do chão onde o pé está: {"lama": fator} e/ou {"impulso": segundos, "fator": f}.
func zona(pe: Vector3) -> Dictionary:
	var r := {}
	for z: Dictionary in _zonas:
		var d: Vector3 = pe - z.centro
		var t: Vector3 = z.tamanho
		if absf(d.dot(z.direita)) <= t.x * 0.5 and absf(d.dot(z.frente)) <= t.z * 0.5 and absf(d.y) <= t.y:
			if z.tipo == "lama":
				r.lama = float(z.fator)
			else:
				r.impulso = float(z.segundos)
				r.fator_impulso = float(z.fator)
	return r


# ------------------------------------------------------------------ acertos

func _acerto_tora(it: Dictionary, c: Vector3) -> Dictionary:
	var eixo: Vector3 = it.frente
	var centro: Vector3 = (it.no as Node3D).position
	var meio := float(it.comprimento) * 0.5
	var perto := centro + eixo * clampf((c - centro).dot(eixo), -meio, meio)
	if perto.distance_to(c) > float(it.raio) + RAIO_DO_CORREDOR:
		return {}
	var vel := cos(TAU * tempo / float(it.periodo) + float(it.fase))
	var lado: Vector3 = (it.direita as Vector3) * (signf(vel) if absf(vel) > 0.15 else signf((c - centro).dot(it.direita)))
	return {"impulso": lado * 9.0 + Vector3.UP * 3.5, "atordoar": 0.6, "tipo": "tora"}


func _acerto_martelo(it: Dictionary, c: Vector3) -> Dictionary:
	var no := it.no as Node3D
	var cabeca: Vector3 = no.position + no.basis * Vector3(0, -float(it.comprimento), 0)
	var eixo: Vector3 = it.frente
	var perto := cabeca + eixo * clampf((c - cabeca).dot(eixo), -1.1, 1.1)
	if perto.distance_to(c) > 0.85 + RAIO_DO_CORREDOR:
		return {}
	var vel := cos(TAU * tempo / float(it.periodo) + float(it.fase))
	return {"impulso": (it.direita as Vector3) * signf(vel) * 12.0 + Vector3.UP * 4.0, "atordoar": 0.7, "tipo": "martelo"}


func _acerto_braco(it: Dictionary, c: Vector3) -> Dictionary:
	var no := it.no as Node3D
	if absf(c.y - (it.p as Vector3).y) > 2.2:
		return {}
	var dir: Vector3 = no.basis * Vector3.RIGHT
	var base := Vector3(it.p.x, 0, it.p.z)
	var plano := Vector3(c.x, 0, c.z)
	var t := clampf((plano - base).dot(dir), 0.0, float(it.comprimento))
	if (base + dir * t).distance_to(plano) > 0.3 + RAIO_DO_CORREDOR or t < 0.6:
		return {}
	var tangente := Vector3.UP.cross(dir) * signf(float(it.velocidade))
	return {"impulso": tangente * 10.0 + Vector3.UP * 2.5, "atordoar": 0.5, "tipo": "braco"}


func _acerto_parede(it: Dictionary, c: Vector3) -> Dictionary:
	var d: Vector3 = c - it.p
	if absf(d.dot(it.frente)) > 0.6 + RAIO_DO_CORREDOR or d.y > float(it.altura):
		return {}
	var x := d.dot(it.direita)
	var meio := _onda(it) * float(it.amplitude)
	if absf(x - meio) < float(it.abertura) * 0.5 - RAIO_DO_CORREDOR * 0.5:
		return {}                                # passou pela abertura
	var volta := -(it.frente as Vector3) * signf(d.dot(it.frente) if absf(d.dot(it.frente)) > 0.05 else 1.0)
	return {"impulso": volta * 7.0 + Vector3.UP * 2.0, "atordoar": 0.45, "tipo": "parede"}


# ------------------------------------------------------------------ montagem

func _mat(cor: Color, metal := 0.0, aspereza := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.metallic = metal
	m.roughness = aspereza
	return m


func _malha(pai: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, base := Basis()) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(base, pos)
	pai.add_child(mi)
	return mi


## Base cujo eixo Y aponta para `eixo`.
func _base_eixo(eixo: Vector3) -> Basis:
	return Basis(Quaternion(Vector3.UP, (eixo as Vector3).normalized()))


## Base da pista no trecho: X = direita, Y = cima, Z = trás.
func _base_lateral(it: Dictionary) -> Basis:
	return Basis(it.direita, Vector3.UP, -(it.frente as Vector3))


func _tora(o: Dictionary) -> Node3D:
	var no := Node3D.new()
	no.name = "Tora"
	add_child(no)
	var cil := CylinderMesh.new()
	cil.top_radius = float(o.raio)
	cil.bottom_radius = float(o.raio)
	cil.height = float(o.comprimento)
	cil.radial_segments = 14
	_malha(no, cil, _mat(COR_TORA, 0.0, 0.9))
	var ponta := CylinderMesh.new()
	ponta.top_radius = float(o.raio) * 0.86
	ponta.bottom_radius = float(o.raio) * 0.86
	ponta.height = 0.06
	for s: float in [-1.0, 1.0]:
		_malha(no, ponta, _mat(COR_TORA_PONTA, 0.0, 0.8), Vector3.UP * s * float(o.comprimento) * 0.5)
	# Faixas de casca: lê o giro de longe.
	var faixa := CylinderMesh.new()
	faixa.top_radius = float(o.raio) * 1.02
	faixa.bottom_radius = float(o.raio) * 1.02
	faixa.height = 0.22
	for k in 3:
		_malha(no, faixa, _mat(COR_TORA.darkened(0.35), 0.0, 1.0), Vector3.UP * (k - 1) * 1.0)
	return no


func _martelo(o: Dictionary) -> Node3D:
	var no := Node3D.new()
	no.name = "Martelo"
	add_child(no)
	no.position = o.p
	var L := float(o.comprimento)
	var haste := BoxMesh.new()
	haste.size = Vector3(0.28, L, 0.28)
	_malha(no, haste, _mat(COR_METAL, 0.6, 0.4), Vector3.DOWN * L * 0.5)
	var cabeca := CylinderMesh.new()
	cabeca.top_radius = 0.85
	cabeca.bottom_radius = 0.85
	cabeca.height = 2.2
	cabeca.radial_segments = 16
	# A cabeça deitada ao longo da frente da pista (bate de lado).
	var deitada := Basis(Vector3.RIGHT, PI * 0.5)
	_malha(no, cabeca, _mat(COR_METAL.lightened(0.15), 0.7, 0.35), Vector3.DOWN * L, deitada)
	var faixa := CylinderMesh.new()
	faixa.top_radius = 0.87
	faixa.bottom_radius = 0.87
	faixa.height = 0.35
	for s: float in [-0.65, 0.0, 0.65]:
		_malha(no, faixa, _mat(COR_PERIGO, 0.2, 0.5), Vector3(0, -L, s), deitada)
	return no


func _braco(o: Dictionary) -> Node3D:
	# Poste físico (o caranguejo contorna) e o braço que varre a pista.
	var poste := StaticBody3D.new()
	poste.name = "PosteDoBraco"
	add_child(poste)
	poste.position = o.p
	var forma := CylinderShape3D.new()
	forma.radius = 0.55
	forma.height = 2.4
	var col := CollisionShape3D.new()
	col.shape = forma
	col.position = Vector3.UP * 1.2
	poste.add_child(col)
	var cil := CylinderMesh.new()
	cil.top_radius = 0.55
	cil.bottom_radius = 0.7
	cil.height = 2.4
	_malha(poste, cil, _mat(COR_METAL, 0.5, 0.4), Vector3.UP * 1.2)
	var no := Node3D.new()
	no.name = "Braco"
	add_child(no)
	no.position = o.p + Vector3.UP * 0.8
	var L := float(o.comprimento)
	var n := 6
	for k in n:
		var bloco := BoxMesh.new()
		bloco.size = Vector3(L / n, 0.5, 0.5)
		_malha(no, bloco, _mat(COR_PERIGO if k % 2 == 0 else COR_PERIGO_2, 0.1, 0.6), Vector3.RIGHT * (k + 0.5) * L / n)
	return no


func _parede(o: Dictionary) -> Dictionary:
	# Duas folhas que fecham a pista e deixam uma abertura de `abertura` m que anda de
	# lado (portas de correr). A largura de cada folha muda: corpo físico com a forma
	# redimensionada a cada passo.
	var folhas: Array = []
	for lado in 2:
		var corpo := AnimatableBody3D.new()
		corpo.name = "Parede"
		corpo.sync_to_physics = false
		add_child(corpo)
		var forma := BoxShape3D.new()
		var col := CollisionShape3D.new()
		col.shape = forma
		corpo.add_child(col)
		var vis := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		vis.mesh = caixa
		vis.material_override = _mat(COR_PAREDE if lado == 0 else COR_PAREDE_2, 0.0, 0.6)
		corpo.add_child(vis)
		var topo := MeshInstance3D.new()
		var faixa := BoxMesh.new()
		topo.mesh = faixa
		topo.material_override = _mat(COR_PERIGO, 0.1, 0.5)
		corpo.add_child(topo)
		folhas.append({"corpo": corpo, "forma": forma, "caixa": caixa, "faixa": faixa, "topo": topo})
	return {"folhas": folhas}


func _mover_parede(it: Dictionary) -> void:
	var meio := _onda(it) * float(it.amplitude)
	var borda := PistaDosCaranguejos.LARGURA * 0.5
	var h := float(it.altura)
	for lado in 2:
		var f: Dictionary = it.folhas[lado]
		var de := -borda if lado == 0 else meio + float(it.abertura) * 0.5
		var ate := meio - float(it.abertura) * 0.5 if lado == 0 else borda
		var largura := maxf(ate - de, 0.1)
		var centro: Vector3 = it.p + (it.direita as Vector3) * (de + ate) * 0.5 + Vector3.UP * h * 0.5
		var corpo := f.corpo as AnimatableBody3D
		corpo.transform = Transform3D(_base_lateral(it), centro)
		(f.forma as BoxShape3D).size = Vector3(largura, h, 1.2)
		(f.caixa as BoxMesh).size = Vector3(largura, h, 1.2)
		(f.faixa as BoxMesh).size = Vector3(largura, 0.25, 1.26)
		(f.topo as Node3D).position = Vector3.UP * (h * 0.5 - 0.125)


func _plataforma(o: Dictionary) -> Node3D:
	var corpo := AnimatableBody3D.new()
	corpo.name = "Plataforma"
	# Movida no passo da física: o motor estima a velocidade e CARREGA quem está em cima.
	corpo.sync_to_physics = true
	add_child(corpo)
	corpo.transform = Transform3D(_base_lateral(o), o.p)
	var t: Vector3 = o.tamanho
	var forma := BoxShape3D.new()
	forma.size = t
	var col := CollisionShape3D.new()
	col.shape = forma
	corpo.add_child(col)
	var caixa := BoxMesh.new()
	caixa.size = t
	_malha(corpo, caixa, _mat(COR_PLATAFORMA, 0.0, 0.85))
	# Bordas listradas (amarelo/preto) nas pontas, onde se pula.
	for s: float in [-1.0, 1.0]:
		for k in 4:
			var b := BoxMesh.new()
			b.size = Vector3(t.x / 4.0, 0.06, 0.6)
			_malha(corpo, b, _mat(COR_PERIGO if k % 2 == 0 else COR_PERIGO_2, 0.1, 0.6),
				Vector3(-t.x * 0.5 + (k + 0.5) * t.x / 4.0, t.y * 0.5 + 0.03, s * (t.z * 0.5 - 0.3)))
	return corpo
