extends Node3D
## Rig rígido de oito patas: o pé apoia durante metade do ciclo e volta pelo ar.
## Fonte geométrica: tools/blender/caranguejo_pet.py. Frente -Z, marcha ±X.
var _corpo: Node3D
var _patas: Array[Dictionary] = []
var _garras: Array[Node3D] = []
var emissores: Array[Node3D] = []
var _fase := 0.0
var _tempo := 0.0
var _peso := 0.0
var _salto := 0.0
var _bolhas := 0.0
## Beliscão (30/09/2026): as pinças sobem e estocam para a frente; 0 = parado.
var _pinca := 0.0
const DURACAO_PINCA := 0.45

func montar(modelo: Node3D) -> void:
	_corpo = modelo.find_child("Corpo", true, false)
	for lado in [-1.0, 1.0]:
		var letra := "E" if lado < 0 else "D"
		for i in 4:
			var tag := "%s_%d" % [letra, i]
			var superior: Node3D = modelo.find_child("Pata_" + tag + "_A", true, false)
			var inferior: Node3D = modelo.find_child("Pata_" + tag + "_B", true, false)
			# Comprimentos e apoio vêm do GLB, para mudar a arte sem duplicar medidas.
			_patas.append({"lado": lado, "i": i, "a": superior, "b": inferior,
				"quadril": superior.position, "joelho": inferior.position,
				"pe": inferior.transform * Vector3.UP,
				"junta": modelo.find_child("Junta_" + tag, true, false)})
		_garras.append(modelo.find_child("Garra_" + letra, true, false))
		emissores.append(modelo.find_child("Bolhas_" + letra, true, false))

func animar(delta: float, velocidade_local: Vector3, no_chao: bool, velocidade_y: float) -> void:
	if _corpo == null:
		return
	_tempo += delta
	_bolhas = maxf(0.0, _bolhas - delta)
	_pinca = maxf(0.0, _pinca - delta)
	var rapidez := Vector2(velocidade_local.x, velocidade_local.z).length()
	_peso = move_toward(_peso, clampf(rapidez / 2.0, 0, 1) if no_chao else 0.0, delta * 7.0)
	_salto = move_toward(_salto, 0.0 if no_chao else 1.0, delta * 9.0)
	# Apoio percorre 0,9 m em MEIO ciclo: ciclo inteiro = 1,8 m.
	# Assim o pé recua à velocidade real do corpo durante a fase de apoio.
	_fase += rapidez * delta / 1.8
	var direcao := signf(velocidade_local.x)
	_corpo.position.y = sin(_tempo * 1.8) * .009 + sin(_fase * TAU * 2) * .025 * _peso - _salto * .06
	_corpo.rotation.z = sin(_fase * TAU) * .025 * _peso
	_corpo.rotation.x = clampf(-velocidade_y * .012, -.12, .12) * _salto
	for p in _patas:
		var lado: float = p.lado
		var i: int = p.i
		var fase := fposmod(_fase + float(i % 2) * .5 + (0.5 if lado < 0 else 0.0), 1.0)
		var passo := (0.5 - fase * 2.0) if fase < .5 else (-.5 + (fase - .5) * 2.0)
		var levantar := sin((fase - .5) * TAU) * .24 if fase > .5 else 0.0
		var quadril: Vector3 = p.quadril
		var pe: Vector3 = p.pe
		pe.x += passo * .9 * direcao * _peso
		pe.y += levantar * _peso + _salto * .32
		pe.x -= lado * .27 * _salto
		# Joelho resolve duas barras de comprimento fixo; evita esticar o exoesqueleto.
		var referencia: Vector3 = p.joelho
		var pe_base: Vector3 = p.pe
		var a := quadril.distance_to(referencia)
		var b := referencia.distance_to(pe_base)
		var eixo := pe - quadril
		var distancia := clampf(eixo.length(), absf(a - b) + .001, a + b - .001)
		eixo = eixo.normalized()
		pe = quadril + eixo * distancia
		var ao_longo := (a * a - b * b + distancia * distancia) / (2.0 * distancia)
		var perpendicular := (Vector3.UP - eixo * eixo.dot(Vector3.UP)).normalized()
		var joelho := quadril + eixo * ao_longo + perpendicular * sqrt(maxf(0, a * a - ao_longo * ao_longo))
		_segmento(p.a, quadril, joelho)
		_segmento(p.b, joelho, pe)
		(p.junta as Node3D).position = joelho
	for i in _garras.size():
		var garra := _garras[i]
		# Beliscão: sobe e estoca à frente num arco curto (preparo → golpe → volta).
		var golpe := sin(clampf(1.0 - _pinca / DURACAO_PINCA, 0.0, 1.0) * PI) if _pinca > 0.0 else 0.0
		var elevacao := -.05 * sin(_tempo * 1.4 + i) - .16 * _salto - .18 * minf(_bolhas, 1.0) - .5 * golpe
		var pivot := Vector3(-.73 if i == 0 else .73, .84, -.45)
		var giro := Basis(Vector3.RIGHT, elevacao)
		garra.transform = Transform3D(giro, pivot - giro * pivot + Vector3(0, 0, -.35 * golpe))

func beliscar() -> void:
	_pinca = DURACAO_PINCA


func preparar_bolhas() -> void:
	_bolhas = 1.4

static func _segmento(no: Node3D, inicio: Vector3, fim: Vector3) -> void:
	var vetor := fim - inicio
	no.transform = Transform3D(Basis(Quaternion(Vector3.UP, vetor.normalized())) * Basis.from_scale(Vector3(1, vetor.length(), 1)), inicio)
