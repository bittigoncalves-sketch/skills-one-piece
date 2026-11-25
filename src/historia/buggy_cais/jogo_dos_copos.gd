class_name JogoDosCopos
extends Node3D
# ============================================================================
#  JOGO DOS COPOS (21/11/2026) — o Buggy põe a pedra sob um dos 3 copos e embaralha; o jogador aponta e aperta E (ou clica). UMA tentativa.
#  LÓGICA PURA (estática, testável): `gerar_trocas`, `aplicar_trocas`. O nó só anima: MOSTRA (o copo da pedra sobe) → EMBARALHA (trocas de lugar em arco, cada vez
#  mais rápidas) → ESCOLHA (espera o jogador) → REVELA (todos sobem) → FIM. Sinal `escolheu(acertou)` ao escolher; `terminou` ao fim da revelação.
#  Os copos são caixas (estética do jogo); o jogador escolhe pelo copo mais perto do RAIO DA MIRA (câmera → frente), a ≤ `RAIO_DA_ESCOLHA`.
#  GATILHO: jogo com mais de 3 copos/rodadas → `n_copos` e `trocas` já são parâmetros; só o raio de escolha muda.
# ============================================================================
signal escolheu(acertou: bool)
signal terminou

enum Fase { PARADO, MOSTRA, EMBARALHA, ESCOLHA, REVELA, FIM }

const N_COPOS := 3
const ESPACO := 0.9                   # m entre os copos
const ALTURA_COPO := 0.55
const LARGURA_COPO := 0.42
const SOBE := 0.75
const T_MOSTRA := 1.5
const T_TROCA_INICIAL := 0.5
const T_TROCA_FINAL := 0.26
const T_REVELA := 1.6
const RAIO_DA_ESCOLHA := 0.55

var trocas_por_jogo := 10
var _rng := RandomNumberGenerator.new()
var _ordem: Array[int] = [0, 1, 2]    # _ordem[slot] = id do copo naquele lugar
var _pedra_no_copo := 1               # id do copo com a pedra
var _trocas: Array[Vector2i] = []
var _copos: Array[Node3D] = []        # por id
var _pedra: MeshInstance3D
var fase := Fase.PARADO
var _t := 0.0
var _i := 0
var escolhido := -1
var acertou := false


# ------------------------------------------------------------------ lógica pura
## `n` trocas entre dois slots DIFERENTES, sem repetir a troca imediatamente anterior (para o olho não ver um vai-e-volta que não embaralha).
static func gerar_trocas(rng: RandomNumberGenerator, n: int, copos := N_COPOS) -> Array[Vector2i]:
	var saida: Array[Vector2i] = []
	while saida.size() < n:
		var a := rng.randi_range(0, copos - 1)
		var b := rng.randi_range(0, copos - 1)
		if a == b:
			continue
		var par := Vector2i(mini(a, b), maxi(a, b))
		if not saida.is_empty() and saida[-1] == par:
			continue
		saida.append(par)
	return saida


## Ordem final dos copos (por slot) depois das trocas.
static func aplicar_trocas(ordem: Array[int], trocas: Array[Vector2i]) -> Array[int]:
	var o := ordem.duplicate()
	for t in trocas:
		var x: int = o[t.x]
		o[t.x] = o[t.y]
		o[t.y] = x
	return o


# ------------------------------------------------------------------ nó
func preparar(semente: int = -1) -> void:
	if semente >= 0:
		_rng.seed = semente
	else:
		_rng.randomize()
	_pedra_no_copo = _rng.randi_range(0, N_COPOS - 1)
	_trocas = gerar_trocas(_rng, trocas_por_jogo)
	_ordem = [0, 1, 2]
	for i in N_COPOS:
		var c := _copo(i)
		add_child(c)
		_copos.append(c)
		c.position = _slot(i)
	_pedra = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.2, 0.2, 0.2)
	_pedra.mesh = b
	_pedra.material_override = _mat(Color(0.55, 0.55, 0.6))
	_pedra.name = "Pedra"
	add_child(_pedra)
	_pedra.position = _slot(_slot_do_copo(_pedra_no_copo)) + Vector3(0, 0.1, 0)


func iniciar() -> void:
	if fase != Fase.PARADO:
		return
	_t = 0.0
	fase = Fase.MOSTRA


func pedra_no_copo() -> int:
	return _pedra_no_copo


func slot_final_da_pedra() -> int:
	return aplicar_trocas([0, 1, 2], _trocas).find(_pedra_no_copo)


func _slot(i: int) -> Vector3:
	return Vector3((i - (N_COPOS - 1) * 0.5) * ESPACO, 0.0, 0.0)


func _slot_do_copo(id: int) -> int:
	return _ordem.find(id)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _copo(id: int) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Copo%d" % id
	var corpo := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(LARGURA_COPO, ALTURA_COPO, LARGURA_COPO)
	corpo.mesh = b
	corpo.material_override = _mat(Color(0.78, 0.2, 0.18))
	corpo.position.y = ALTURA_COPO * 0.5
	raiz.add_child(corpo)
	var faixa := MeshInstance3D.new()
	var f := BoxMesh.new()
	f.size = Vector3(LARGURA_COPO + 0.02, 0.1, LARGURA_COPO + 0.02)
	faixa.mesh = f
	faixa.material_override = _mat(Color(0.95, 0.85, 0.3))
	faixa.position.y = ALTURA_COPO * 0.7
	raiz.add_child(faixa)
	return raiz


func _process(delta: float) -> void:
	step(delta)


## Avança a animação `delta` s (separado de `_process` para os testes andarem sem relógio).
func step(delta: float) -> void:
	match fase:
		Fase.MOSTRA:
			_t += delta
			var k := sin(clampf(_t / T_MOSTRA, 0.0, 1.0) * PI)       # sobe e desce
			_copos[_pedra_no_copo].position.y = SOBE * k
			if _t >= T_MOSTRA:
				_copos[_pedra_no_copo].position.y = 0.0
				_t = 0.0
				_i = 0
				fase = Fase.EMBARALHA
		Fase.EMBARALHA:
			var dur := lerpf(T_TROCA_INICIAL, T_TROCA_FINAL, float(_i) / maxf(float(_trocas.size() - 1), 1.0))
			_t += delta
			var troca := _trocas[_i]
			var k2 := clampf(_t / dur, 0.0, 1.0)
			var id_a: int = _ordem[troca.x]
			var id_b: int = _ordem[troca.y]
			var pa := _slot(troca.x)
			var pb := _slot(troca.y)
			var arco := sin(k2 * PI) * 0.35
			_copos[id_a].position = pa.lerp(pb, k2) + Vector3(0, 0, arco)
			_copos[id_b].position = pb.lerp(pa, k2) - Vector3(0, 0, arco)
			if k2 >= 1.0:
				_ordem[troca.x] = id_b
				_ordem[troca.y] = id_a
				_copos[id_a].position = pb
				_copos[id_b].position = pa
				_t = 0.0
				_i += 1
				if _i >= _trocas.size():
					_pedra.visible = false                  # a pedra fica escondida sob o copo
					fase = Fase.ESCOLHA
		Fase.REVELA:
			_t += delta
			var k3 := sin(clampf(_t / T_REVELA, 0.0, 1.0) * PI)
			for id in N_COPOS:
				if id == _pedra_no_copo or id == escolhido:
					_copos[id].position.y = SOBE * k3
			_pedra.visible = true
			_pedra.position = _slot(_slot_do_copo(_pedra_no_copo)) + Vector3(0, 0.1, 0)
			if _t >= T_REVELA:
				fase = Fase.FIM
				terminou.emit()


## O jogador escolheu o copo `id` (0–2). Só vale na ESCOLHA; devolve false fora dela.
func escolher(id: int) -> bool:
	if fase != Fase.ESCOLHA or id < 0 or id >= N_COPOS:
		return false
	escolhido = id
	acertou = id == _pedra_no_copo
	fase = Fase.REVELA
	_t = 0.0
	escolheu.emit(acertou)
	return true


## O copo mais perto do raio da mira (origem + direção, em coordenadas globais), ou -1 se nenhum está a ≤ `RAIO_DA_ESCOLHA`.
func copo_da_mira(origem: Vector3, direcao: Vector3) -> int:
	var melhor := -1
	var menor := RAIO_DA_ESCOLHA
	for id in N_COPOS:
		var centro := _copos[id].global_position + Vector3(0, ALTURA_COPO * 0.5, 0)
		var d := _distancia_ao_raio(centro, origem, direcao)
		if d < menor:
			menor = d
			melhor = id
	return melhor


static func _distancia_ao_raio(p: Vector3, o: Vector3, dir: Vector3) -> float:
	var d := dir.normalized()
	var t := maxf((p - o).dot(d), 0.0)
	return p.distance_to(o + d * t)


func _unhandled_input(evento: InputEvent) -> void:
	if fase != Fase.ESCOLHA:
		return
	var tecla := evento as InputEventKey
	var clique := evento as InputEventMouseButton
	var apertou := (tecla != null and tecla.pressed and not tecla.echo and (tecla.keycode == KEY_E or tecla.physical_keycode == KEY_E)) \
		or (clique != null and clique.pressed and clique.button_index == MOUSE_BUTTON_LEFT)
	if not apertou:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var id := copo_da_mira(cam.global_position, -cam.global_basis.z)
	if id >= 0 and escolher(id):
		get_viewport().set_input_as_handled()
