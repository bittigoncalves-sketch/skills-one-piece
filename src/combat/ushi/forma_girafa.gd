class_name FormaGirafa
extends Node3D
## TERCEIRA FORMA da Ushi Ushi no Mi (21/11/2026): a GIRAFA, quadrúpede. Humano → girafa humanoide (a forma do mod) → girafa.
## Corpo procedural (caixas + `UshiMateriais.pele`), pernas de duas juntas, cauda e o `UshiPescoco`. Segue o `_char_model` do jogador (posição
## e rumo; o jogador continua sendo a cápsula) e esconde o corpo como as outras formas (`FormaZoan.META_ATIVA`).
## A MARCHA é desenhada aqui: o galope (duas pernas da frente, depois as de trás) acompanha a distância percorrida, não o relógio — parado,
## respira; no ar, recolhe as pernas. Quem golpeia manda no pescoço (`pescoco`) e no tronco (`inclinacao_do_tronco`).
const ESCALA := 0.95
const PERNA := 0.66                  # coxa e canela, cada uma
const ALTURA_DO_TRONCO := 1.38
const NOME := "FormaGirafa"

var pescoco: UshiPescoco
var inclinacao_do_tronco := 0.0      # rad (positivo = ergue a frente)
var fase := 0.0                      # fase da marcha (rad)
var coice_t := -1.0                  # s desde o início do X (Martelada): >= 0 faz a pata traseira direita dar o COICE da preparação; -1 = desligado
var peso_do_golpe := 0.0             # 0..1: durante o golpe a marcha cede ao pescoço (o corpo firma as patas)
var _ator: Node3D
var _tronco: Node3D
var _patas: Array = []               # [{coxa, canela, frente, lado}]
var _cauda: Node3D
var _suave := 0.0                    # velocidade horizontal suavizada


static func aplicar(ator: Node3D, ligar: bool) -> FormaGirafa:
	var atual := ator.get_node_or_null(NOME) as FormaGirafa
	if atual != null:
		atual.name = "FormaGirafaRetirada_%d" % atual.get_instance_id()
		atual.visible = false
		atual.queue_free()
		atual = null
	if ligar:
		atual = FormaGirafa.new()
		atual.name = NOME
		ator.add_child(atual)
		atual._montar(ator)
	return atual


func _montar(ator: Node3D) -> void:
	_ator = ator
	_tronco = Node3D.new()
	_tronco.position = Vector3(0, ALTURA_DO_TRONCO, 0)
	add_child(_tronco)
	UshiPescoco._caixa(_tronco, Vector3(0.62, 0.64, 1.55), Vector3.ZERO, UshiMateriais.pele())
	UshiPescoco._caixa(_tronco, Vector3(0.5, 0.3, 0.5), Vector3(0, 0.38, -0.5), UshiMateriais.pele())       # cernelha (a frente é mais alta)
	pescoco = UshiPescoco.new(1.55, 0.30)
	pescoco.position = Vector3(0, 0.4, -0.62)
	pescoco.pitch = 0.42
	_tronco.add_child(pescoco)
	_cauda = Node3D.new()
	_cauda.position = Vector3(0, 0.2, 0.78)
	_tronco.add_child(_cauda)
	UshiPescoco._caixa(_cauda, Vector3(0.07, 0.07, 0.62), Vector3(0, -0.08, 0.3), UshiMateriais.pele())
	UshiPescoco._caixa(_cauda, Vector3(0.14, 0.14, 0.2), Vector3(0, -0.1, 0.68), UshiMateriais.escuro())
	for frente in [true, false]:
		for lado in [-1.0, 1.0]:
			var coxa := Node3D.new()
			coxa.position = Vector3(lado * 0.23, -0.26, -0.58 if frente else 0.6)
			_tronco.add_child(coxa)
			UshiPescoco._caixa(coxa, Vector3(0.17, PERNA, 0.17), Vector3(0, -PERNA * 0.5, 0), UshiMateriais.pele())
			var canela := Node3D.new()
			canela.position = Vector3(0, -PERNA, 0)
			coxa.add_child(canela)
			UshiPescoco._caixa(canela, Vector3(0.13, PERNA, 0.13), Vector3(0, -PERNA * 0.5, 0), UshiMateriais.pele())
			UshiPescoco._caixa(canela, Vector3(0.18, 0.1, 0.24), Vector3(0, -PERNA - 0.04, -0.03), UshiMateriais.escuro())       # casco
			_patas.append({"coxa": coxa, "canela": canela, "frente": frente, "lado": lado})
	_seguir(0.0)


func _process(delta: float) -> void:
	_seguir(delta)


func _seguir(delta: float) -> void:
	if not is_instance_valid(_ator):
		return
	var raiz := _ator.get("_char_model") as Node3D
	if raiz == null:
		return
	var cam: Variant = _ator.get("_camera")
	visible = not (cam != null and cam.has_method("em_primeira_pessoa") and cam.em_primeira_pessoa())
	var esc := float(McEntidade.de(_ator).escala(&"height")) * ESCALA
	global_transform = Transform3D(raiz.global_basis.orthonormalized() * Basis.from_scale(Vector3.ONE * esc), raiz.global_position)
	var v: Vector3 = _ator.get("velocity") if _ator.get("velocity") != null else Vector3.ZERO
	var rapido := Vector2(v.x, v.z).length()
	var no_chao: bool = _ator.is_on_floor() if _ator.has_method("is_on_floor") else true
	_suave = lerpf(_suave, rapido if no_chao else rapido * 0.5, clampf(delta * 10.0, 0.0, 1.0))
	fase += _suave * delta * 1.9
	_marchar(no_chao, delta)


func _marchar(no_chao: bool, delta: float) -> void:
	var mov := clampf(_suave / 6.0, 0.0, 1.0) * (1.0 - peso_do_golpe * 0.85)
	var t := Time.get_ticks_msec() * 0.001
	for p: Dictionary in _patas:
		# Galope: as duas da frente andam juntas (com um pequeno desencontro entre lados), as de trás defasadas em ~PI.
		var defasagem := (0.0 if p.frente else PI) + (0.35 if p.lado > 0.0 else 0.0)
		var s := sin(fase + defasagem)
		var coxa: Node3D = p.coxa
		var canela: Node3D = p.canela
		if coice_t >= 0.0 and not p.frente and p.lado > 0.0:
			var kc := _quadro_do_coice(coice_t)
			coxa.rotation.x = kc.x
			canela.rotation.x = kc.y
			continue
		if not no_chao:
			coxa.rotation.x = lerpf(coxa.rotation.x, -0.9 if p.frente else 0.7, clampf(delta * 12.0, 0.0, 1.0))
			canela.rotation.x = lerpf(canela.rotation.x, 1.1, clampf(delta * 12.0, 0.0, 1.0))
		else:
			coxa.rotation.x = s * 0.85 * mov
			canela.rotation.x = maxf(0.0, -cos(fase + defasagem)) * 1.1 * mov * (1.0 if p.frente else -0.8)
	# O tronco quica duas vezes por passada e a frente sobe e desce com o galope; o pescoço balança contra o corpo.
	_tronco.position.y = ALTURA_DO_TRONCO + absf(sin(fase)) * 0.09 * mov + sin(t * 1.6) * 0.008
	_tronco.rotation.x = inclinacao_do_tronco + sin(fase * 1.0 + 0.8) * 0.08 * mov
	_cauda.rotation.x = -0.3 - 0.5 * mov + sin(fase * 2.0) * 0.15 * mov
	_cauda.rotation.y = sin(t * 2.2) * 0.25
	if peso_do_golpe < 0.01:
		pescoco.pitch = 0.42 + 0.22 * mov + sin(fase + 1.2) * 0.1 * mov + sin(t * 0.9) * 0.02
		pescoco.yaw = sin(t * 0.6) * 0.03
		pescoco.roll = 0.0
		pescoco.extensao = 1.0 - 0.06 * mov


## Coice (plano do Codex, 21/11/2026): [t, coxa°, canela°] — arma a pata (coxa à frente, canela dobrada para trás), estica para trás uma vez, volta ao apoio.
const COICE := [[0.0, 0.0, 0.0], [0.12, 20.0, -35.0], [0.24, -40.0, -5.0], [0.38, 0.0, 0.0]]


static func _quadro_do_coice(t: float) -> Vector2:
	var i := 0
	while i < COICE.size() - 2 and t > float(COICE[i + 1][0]):
		i += 1
	var a: Array = COICE[i]
	var b: Array = COICE[i + 1]
	var u := smoothstep(0.0, 1.0, inverse_lerp(float(a[0]), float(b[0]), clampf(t, float(a[0]), float(b[0]))))
	return Vector2(lerpf(float(a[1]), float(b[1]), u), lerpf(float(a[2]), float(b[2]), u)) * (PI / 180.0)


## Fim do nariz no mundo / base do pescoço (o módulo mede o golpe por aqui).
func ponta() -> Vector3:
	return pescoco.ponta()


func raiz_do_pescoco() -> Vector3:
	return pescoco.raiz()
