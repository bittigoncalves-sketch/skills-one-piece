extends Node3D
# ============================================================================
#  CARANGUEJOS GIGANTES DA FOSSA (15/10/2026) — decoração viva das zonas mais fundas.
#
#  Decisões do dono: são NEUTROS (só decoração: não atacam, não fogem, não dão XP) e
#  moram só na fossa, onde o fundo passa de -70 m (`LIMITE_DO_FUNDO`). O mar aberto a
#  -64 m e a plataforma rasa ficam livres deles.
#
#  O corpo é o "caranguejo_grande" da loja (o mesmo do pet e da corrida), esticado
#  de 1,3× a 2,0× o tamanho padrão dele, com o animador de oito patas dele andando de
#  lado. Eles só existem com a câmera SUBMERSA, em blocos de 64 m em volta dela (como os
#  cardumes), determinísticos: o mesmo bloco sempre planta os mesmos caranguejos.
#
#  DESEMPENHO: o modelo tem ~35 mil triângulos, então no máximo `POR_BLOCO` por bloco e
#  só os blocos perto da câmera; além de 90 m a névoa da água (E7) já os apagou, e a
#  distância de visibilidade corta o desenho. GATILHO: se a captura do mar mostrar mais
#  de ~1 ms de GPU por causa deles, baixar `POR_BLOCO` ou o raio de montagem.
# ============================================================================

const MODELO := "caranguejo_grande"
const ANIMADOR := preload("res://src/historia/pets/animador_caranguejo.gd")
## O fundo tem que estar ABAIXO disto (y do mundo) para valer como fossa.
const LIMITE_DO_FUNDO := -70.0
const BLOCO := 64.0
const RAIO_MONTAR := 110.0
const RAIO_SOLTAR := 170.0
const SEMENTE := 15102026
const POR_BLOCO := 2
const TENTATIVAS := 6
const ESCALA := Vector2(1.3, 2.0)
const VELOCIDADE := 0.7                # m/s, de lado
const VISIVEL_ATE := 90.0

var relevo: RelevoMarinho
var jogador_de: Callable
var camera_de: Callable
var _bib: BibliotecaDeModelos
var _blocos := {}                      # Vector2i → Array[Dictionary]
var _relogio := 0.0


func ligar(contexto: Dictionary, campo: RelevoMarinho, jogador: Callable) -> void:
	relevo = campo
	jogador_de = jogador
	_bib = contexto.get("bib")


## Onde o bloco `c` planta caranguejos: [{pos: Vector3, yaw, escala, semente}]. Puro
## (só lê o relevo), então o teste confere sem montar nó nenhum.
func planejar(c: Vector2i) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if relevo == null:
		return saida
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(c.x, c.y, SEMENTE))
	var origem := Vector2(c) * BLOCO
	for k in TENTATIVAS:
		var x := origem.x + rng.randf() * BLOCO
		var z := origem.y + rng.randf() * BLOCO
		var y := relevo.altura(x, z)
		var yaw := rng.randf() * TAU
		var escala := rng.randf_range(ESCALA.x, ESCALA.y)
		var semente := rng.randi()
		if y >= LIMITE_DO_FUNDO or saida.size() >= POR_BLOCO:
			continue
		saida.append({"pos": Vector3(x, y, z), "yaw": yaw, "escala": escala, "semente": semente})
	return saida


func _process(delta: float) -> void:
	if relevo == null or _bib == null:
		return
	var cam := _camera()
	if cam == null:
		return
	var p := cam.global_position
	visible = p.y < relevo.nivel + 0.3
	if not visible:
		return
	_relogio -= delta
	if _relogio <= 0.0:
		_relogio = 0.5
		montar_em_volta(Vector2(p.x, p.z), RAIO_MONTAR, 2)
		_soltar_longe(Vector2(p.x, p.z))
	for c in _blocos:
		for caranguejo: Dictionary in _blocos[c]:
			_andar(caranguejo, delta)


## Garante os blocos em volta de p (testes e capturas). `maximo` limita quantos blocos
## nascem por chamada (o jogo espalha o custo em vários quadros).
func montar_em_volta(p: Vector2, raio := RAIO_MONTAR, maximo := 9999) -> void:
	var r := int(ceil(raio / BLOCO))
	var c0 := Vector2i(floori(p.x / BLOCO), floori(p.y / BLOCO))
	var montados := 0
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			var c := c0 + Vector2i(i, j)
			if not _blocos.has(c) and (Vector2(c) * BLOCO + Vector2.ONE * BLOCO * 0.5).distance_to(p) < raio + BLOCO * 0.71 \
					and montados < maximo:
				_blocos[c] = _montar_bloco(c)
				montados += 1


func _soltar_longe(p: Vector2) -> void:
	for c in _blocos.keys():
		if (Vector2(c) * BLOCO + Vector2.ONE * BLOCO * 0.5).distance_to(p) > RAIO_SOLTAR:
			for caranguejo: Dictionary in _blocos[c]:
				(caranguejo["no"] as Node).queue_free()
			_blocos.erase(c)


## Quantos caranguejos estão montados agora (teste e medição).
func quantos() -> int:
	var n := 0
	for c in _blocos:
		n += (_blocos[c] as Array).size()
	return n


func _montar_bloco(c: Vector2i) -> Array[Dictionary]:
	var feitos: Array[Dictionary] = []
	for plano in planejar(c):
		var modelo := _bib.instanciar(MODELO) if _bib != null else null
		if modelo == null:
			continue
		var raiz := Node3D.new()
		raiz.name = "CaranguejoGigante"
		raiz.add_child(modelo)
		var base := _bib.tamanho_padrao(MODELO)
		var original: Vector3 = _bib.info(MODELO)["tamanho"]
		if original.y > 0.0:
			modelo.scale = Vector3(base.y / original.y, base.y / original.y, base.y / original.y)
		raiz.scale = Vector3.ONE * float(plano["escala"])
		var animador := ANIMADOR.new()
		animador.name = "Patas"
		modelo.add_child(animador)
		animador.call("montar", modelo)
		raiz.add_to_group("so_submerso")
		add_child(raiz)
		raiz.global_position = plano["pos"]
		raiz.rotation.y = plano["yaw"]
		_cortar_longe(raiz)
		var rng := RandomNumberGenerator.new()
		rng.seed = plano["semente"]
		feitos.append({"no": raiz, "animador": animador, "dir": 1.0 if rng.randf() < 0.5 else -1.0,
			"troca_em": rng.randf_range(3.0, 8.0), "rng": rng, "casa": plano["pos"]})
	return feitos


func _cortar_longe(no: Node) -> void:
	if no is GeometryInstance3D:
		(no as GeometryInstance3D).visibility_range_end = VISIVEL_ATE
		(no as GeometryInstance3D).visibility_range_end_margin = 10.0
	for f in no.get_children():
		_cortar_longe(f)


## Um passo: anda de lado (o animador anda ±X), troca de sentido de tempos em tempos e
## NUNCA sai da fossa nem se afasta muito de casa — vira e volta.
func _andar(c: Dictionary, delta: float) -> void:
	var no: Node3D = c["no"]
	if not is_instance_valid(no):
		return
	c["troca_em"] = float(c["troca_em"]) - delta
	var rng: RandomNumberGenerator = c["rng"]
	var casa: Vector3 = c["casa"]
	if float(c["troca_em"]) <= 0.0:
		c["troca_em"] = rng.randf_range(3.0, 8.0)
		c["dir"] = -float(c["dir"]) if rng.randf() < 0.7 else float(c["dir"])
		no.rotation.y += rng.randf_range(-0.6, 0.6)
	var lado := no.global_transform.basis.x.normalized() * float(c["dir"])
	var alvo := no.global_position + lado * VELOCIDADE * delta
	if relevo.altura(alvo.x, alvo.z) >= LIMITE_DO_FUNDO or Vector2(alvo.x - casa.x, alvo.z - casa.z).length() > 14.0:
		c["dir"] = -float(c["dir"])           # beirou a borda da fossa: volta
		alvo = no.global_position
	alvo.y = relevo.altura(alvo.x, alvo.z)
	no.global_position = alvo
	(c["animador"] as Node).call("animar", delta, Vector3(float(c["dir"]) * VELOCIDADE, 0, 0), true, 0.0)


func _camera() -> Camera3D:
	if camera_de.is_valid():
		return camera_de.call()
	return get_viewport().get_camera_3d() if is_inside_tree() else null
