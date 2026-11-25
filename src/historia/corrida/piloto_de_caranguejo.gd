extends RefCounted
# ============================================================================
#  PILOTO DE CARANGUEJO — a IA dos rivais da corrida (06/10/2026).
#
#  Decisão do dono: rivais com IA. Também é o piloto automático do teste que corre a
#  pista inteira com o caranguejo do JOGADOR (prova de que a pista é completável).
#
#  Segue o `caminho` da pista (pontos LOCAIS, com os pulos marcados): mira o ponto com o
#  desvio de raia dele, corre sempre, pula na marca. Nas plataformas móveis ESPERA a
#  plataforma alinhar — mirando onde ela vai estar quando ele cair — e só então corre e
#  pula. Erra às vezes (pulo cedo ou tarde) por sorteio próprio: cada rival tem seu
#  jeito, e a mesma semente repete a corrida.
#
#  Só decide o comando ({dir, correr, saltar}); quem move é a locomoção da montaria.
# ============================================================================

const PLATAFORMA_ALINHADA := 1.8     # m de desvio lateral aceitos para pular nela
const ESPERA_ANTES_DO_PULO := 3.6    # m: espera aqui para dar tempo de embalar
const VOO := 0.45                    # s no ar num pulo de vão
const VELOCIDADE := 8.5              # m/s correndo (perfil do caranguejo)

var caminho: Array = []
var obstaculos: Node = null          # ObstaculosDaPista
var indice := 0
var raia := 0.0                      # −1..1: fração do "livre" do ponto
var erro := 0.04                     # chance de errar o momento de um pulo
var parado := 0.0                    # s sem avançar de ponto (o controlador reposiciona)
var _rng := RandomNumberGenerator.new()
var _desvio_do_pulo := 0.0
var _rumo_do_pulo := Vector3.ZERO      # no ar, segue reto: virar no ar encurta o pulo


func configurar(semente: int, raia_: float, erro_: float) -> void:
	_rng.seed = semente
	raia = raia_
	erro = erro_
	_sortear_pulo()


## Volta a seguir a partir do ponto `i` (reaparecimento num portão).
func recomecar(i: int) -> void:
	indice = clampi(i, 0, caminho.size() - 1)
	parado = 0.0
	_sortear_pulo()
	_rumo_do_pulo = Vector3.ZERO


func _sortear_pulo() -> void:
	_desvio_do_pulo = _rng.randf_range(-0.9, 0.7) if _rng.randf() < erro else 0.0


func _avancar() -> void:
	indice = mini(indice + 1, caminho.size() - 1)
	parado = 0.0
	_sortear_pulo()


## O comando deste quadro. `pe` = pé do caranguejo (local da pista); `vel` = velocidade.
func comando(pe: Vector3, vel: Vector3, no_chao: bool, delta: float) -> Dictionary:
	parado += delta
	if _rumo_do_pulo != Vector3.ZERO:
		if not no_chao or vel.y > 0.5:
			return {"dir": _rumo_do_pulo, "correr": true, "saltar": false}
		_rumo_do_pulo = Vector3.ZERO
	var guarda := 0
	while guarda < 6 and _alcancou(pe):
		_avancar()
		guarda += 1
	var w: Dictionary = caminho[indice]
	var wp: Vector3 = w.p
	var eixo := _eixo(indice)
	var alvo := _alvo(w, eixo)
	var correr := true
	var saltar := false
	if w.salto:
		var falta := (wp - pe).dot(eixo)
		var rapidez := Vector2(vel.x, vel.z).length()
		var margem := 0.1 + rapidez * 0.02 + _desvio_do_pulo
		if w.has("mira_plataforma"):
			# Onde a plataforma vai estar quando ele cair (tempo até a borda + voo).
			var quando := maxf(falta, 0.0) / VELOCIDADE + VOO
			var destino: Vector3 = obstaculos.posicao_da_plataforma(int(w.mira_plataforma), quando)
			var lado := eixo.cross(Vector3.UP)
			var desvio := (destino - pe).dot(lado)
			alvo = wp + lado * clampf(desvio, -2.0, 2.0)
			if absf(desvio) > PLATAFORMA_ALINHADA:
				if falta < ESPERA_ANTES_DO_PULO + 1.0:
					# Desalinhada: espera recuado, ainda dá tempo de embalar depois.
					var recuo := wp - eixo * ESPERA_ANTES_DO_PULO + lado * clampf(desvio, -2.0, 2.0)
					var d := recuo - pe
					d.y = 0.0
					return {"dir": d.normalized() * clampf(d.length(), 0.0, 1.0) if d.length() > 0.3 else Vector3.ZERO,
						"correr": false, "saltar": false}
		if falta < margem:
			saltar = no_chao
			if saltar:
				# Pula no rumo da PISTA, não no da velocidade: chegando de lado, no ar o desvio
				# se desfaz; seguir a velocidade fazia pousar fora da linha e virar zigue-zague.
				_rumo_do_pulo = eixo
			if saltar or falta < -1.6:
				_avancar()
	elif w.has("plataforma") and obstaculos != null:
		# Em cima da plataforma: anda com ela (o meio dela agora).
		alvo = obstaculos.posicao_da_plataforma(int(w.plataforma))
	var dir := alvo - pe
	dir.y = 0.0
	# Misturar com o próximo ponto (curva suave) só em pista aberta; no parkour (livre 0)
	# cortar caminho tira o caranguejo da linha do pulo.
	if dir.length() < 2.5 and indice + 1 < caminho.size() and not w.salto and float(w.get("livre", 0.0)) > 0.0:
		var depois := _alvo(caminho[indice + 1], _eixo(indice + 1)) - pe
		depois.y = 0.0
		dir = dir.lerp(depois, 0.5)
	return {"dir": dir.normalized() if dir.length() > 0.05 else Vector3.ZERO, "correr": correr, "saltar": saltar}


## Ponto de pulo só conta quando ele PULA (no comando); os outros, ao passar.
func _alcancou(pe: Vector3) -> bool:
	var w: Dictionary = caminho[indice]
	if w.salto or indice >= caminho.size() - 1:
		return false
	if w.has("plataforma"):
		# Sobre a plataforma: passa ao chegar perto do meio dela.
		var c: Vector3 = obstaculos.posicao_da_plataforma(int(w.plataforma)) if obstaculos != null else w.p
		var dd := pe - c
		dd.y = 0.0
		return dd.dot(_eixo(indice)) > -1.0
	var d := pe - (w.p as Vector3)
	var plano := Vector3(d.x, 0, d.z)
	return plano.dot(_eixo(indice)) > -1.0 or plano.length() < 2.0


## Direção da pista neste ponto (dele para o próximo, no plano).
func _eixo(i: int) -> Vector3:
	var a: Vector3 = caminho[i].p
	var b: Vector3 = caminho[mini(i + 1, caminho.size() - 1)].p
	if i + 1 >= caminho.size():
		a = caminho[maxi(i - 1, 0)].p
		b = caminho[i].p
	var e := b - a
	e.y = 0.0
	return e.normalized() if e.length() > 0.01 else Vector3.FORWARD


func _alvo(w: Dictionary, eixo: Vector3) -> Vector3:
	return (w.p as Vector3) + eixo.cross(Vector3.UP) * raia * float(w.get("livre", 0.0))
