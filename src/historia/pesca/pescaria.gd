class_name Pescaria
extends Node
# ============================================================================
#  PESCARIA — o minigame de pesca do Modo História (03/10/2026).
#
#  Pedido do dono: minigame de pesca com a vara (dada de graça pelo pescador,
#  equipada no N, ativa na barra 1–6). Decisão dele: "Tensão da linha" —
#    clique  → ARREMESSA a boia na água à frente (até `ALCANCE`);
#    espera  → beliscadas falsas e, de 2 a 6 s, a MORDIDA (a boia afunda, "ploc");
#    clique na janela da mordida → FISGA; antes dela → recolhe (cedo demais);
#    briga   → segurar recolhe, soltar dá linha (`TensaoDaLinha`);
#    pegou   → o peixe salta para a mão e vai para o inventário (aba PESCA).
#
#  Só funciona com a vara ATIVA (`capacidades.can_fish`) e o corpo livre (fora da
#  água funda, do leme e da sela). Trocar de item, nadar ou subir no barco recolhe
#  a linha na hora. Afastar-se demais da boia arrebenta a linha.
#
#  O desenho é do `VaraDePescaVisual`; a pose dos braços, da `PescaPoses` (lida
#  pelo animador nas metas `pesca_*` do jogador); o HUD, do `PescaHud`.
# ============================================================================

signal aviso(texto: String)
signal pescou(peixe_id: String)

enum Estado { PARADO, ARREMESSANDO, ESPERANDO, MORDENDO, BRIGANDO, RECOLHENDO }

## Distâncias tentadas para a boia, da mais longe à mais perto (m, no plano).
const ALCANCE: Array[float] = [14.0, 12.0, 10.0, 8.5, 7.0, 5.5, 4.0]
const ESPERA := Vector2(2.0, 6.0)            # s até a mordida de verdade
const JANELA_DA_MORDIDA := 0.8               # s para clicar depois que afunda
const TEMPO_DO_ARREMESSO := 0.75             # s: 0,3 levando a vara + 0,45 de voo
const SOLTA_A_BOIA := 0.3                    # s do arremesso em que a boia sai
const TEMPO_DE_RECOLHER := 0.35
## Mais longe que isto da boia, a linha arrebenta.
const DISTANCIA_MAXIMA := 26.0
## Ângulo da vara acima do horizonte (graus) em cada momento.
const ANGULO_SEGURA := 35.0
const ANGULO_MORDIDA := 22.0
const ANGULO_PUXANDO := 55.0
const ANGULO_ACIMA := 115.0
const ANGULO_CHICOTE := 12.0
const ACAO := &"combate_atacar"

var progressao: ProgressaoDoPersonagem
var biblioteca: BibliotecaDeModelos
## Devolve o jogador local (Player) ou null.
var jogador_de: Callable
## Testes: 1 = clique segurado, 0 = solto, −1 = lê o mouse de verdade.
var botao_forcado := -1

var estado: Estado = Estado.PARADO
var tensao: TensaoDaLinha = null
var peixe_id := ""
## Onde a boia está (mundo) e para onde foi arremessada.
var posicao_da_boia := Vector3.ZERO
var alvo := Vector3.ZERO

var _visual: VaraDePescaVisual
var _rng := RandomNumberGenerator.new()
var _t := 0.0                    # tempo no estado
var _espera := 0.0
var _beliscadas: Array[float] = []
var _beliscada_ate := 0.0
var _botao_antes := false
var _botao := false
var _de := Vector3.ZERO          # início do voo / do recolher
var _perto := Vector3.ZERO       # aonde a boia vem quando a barra enche
var _respingo_em := 0.0


func _ready() -> void:
	_rng.randomize()
	_visual = VaraDePescaVisual.new()
	_visual.name = "VaraDePescaVisual"
	_visual.biblioteca = biblioteca
	add_child(_visual)


func ocupada() -> bool:
	return estado != Estado.PARADO


func visual() -> VaraDePescaVisual:
	return _visual


## Semente fixa (testes).
func semear(semente: int) -> void:
	_rng.seed = semente


## Texto da dica do centro inferior ("" = nada a dizer).
func dica() -> String:
	var j := _jogador()
	if j == null or not _vara_na_mao(j):
		return ""
	match estado:
		Estado.PARADO:
			return "Clique: arremessar a linha na água"
		Estado.ESPERANDO:
			return "Espere a boia afundar…  (clique recolhe)"
		Estado.MORDENDO:
			return "MORDEU! Clique!"
		Estado.BRIGANDO:
			return "Segure: recolher  ·  Solte: dar linha  ·  verde = puxando o peixe"
	return ""


func _physics_process(delta: float) -> void:
	var j := _jogador()
	var na_mao := j != null and _vara_na_mao(j)
	var livre := na_mao and _corpo_livre(j)
	if ocupada() and not livre:
		_cancelar()
	_marcar_pose(j, livre)
	if not livre:
		_botao_antes = false
		return
	_botao = _ler_botao()
	var apertou := _botao and not _botao_antes
	_botao_antes = _botao
	_t += delta
	match estado:
		Estado.PARADO:
			if apertou:
				arremessar()
		Estado.ARREMESSANDO:
			_voar(j)
		Estado.ESPERANDO:
			_esperar(apertou)
		Estado.MORDENDO:
			# A boia AFUNDA e treme enquanto a janela dura.
			posicao_da_boia = Vector3(alvo.x, _superficie(alvo) - 0.18 + sin(_t * 40.0) * 0.02, alvo.z)
			if apertou:
				_fisgar()
			elif _t >= JANELA_DA_MORDIDA:
				aviso.emit("O peixe soltou a isca")
				_comecar_espera()
		Estado.BRIGANDO:
			_brigar(j, delta)
		Estado.RECOLHENDO:
			var u := clampf(_t / TEMPO_DE_RECOLHER, 0.0, 1.0)
			posicao_da_boia = _de.lerp(_visual.ponteira(), u) + Vector3.UP * sin(u * PI) * 0.6
			if u >= 1.0:
				_ir(Estado.PARADO)
	if ocupada() and estado != Estado.ARREMESSANDO \
			and _plano(j.global_position).distance_to(_plano(posicao_da_boia)) > DISTANCIA_MAXIMA:
		aviso.emit("Longe demais: a linha arrebentou")
		AudioFX.snap(self, _visual.ponteira())
		_ir(Estado.PARADO)


func _process(_delta: float) -> void:
	var j := _jogador()
	var na_mao := j != null and _vara_na_mao(j) and _corpo_livre(j)
	_visual.segurar_em(_mao(j) if na_mao else null)
	if not na_mao:
		_visual.sem_linha()
		_visual.esconder_boia()
		return
	var corpo := _base_do_corpo(j)
	var angulo := ANGULO_SEGURA
	match estado:
		Estado.ARREMESSANDO:
			var f := clampf(_t / TEMPO_DO_ARREMESSO, 0.0, 1.0)
			if f < 0.45:
				angulo = lerpf(ANGULO_SEGURA, ANGULO_ACIMA, smoothstep(0.0, 0.45, f))
			elif f < 0.7:
				angulo = lerpf(ANGULO_ACIMA, ANGULO_CHICOTE, smoothstep(0.45, 0.7, f))
			else:
				angulo = lerpf(ANGULO_CHICOTE, ANGULO_SEGURA, smoothstep(0.7, 1.0, f))
		Estado.MORDENDO:
			angulo = ANGULO_MORDIDA
		Estado.BRIGANDO, Estado.RECOLHENDO:
			angulo = ANGULO_PUXANDO
	var frente := -corpo.z
	var rad := deg_to_rad(angulo)
	var direcao := frente * cos(rad) + Vector3.UP * sin(rad)
	if estado == Estado.BRIGANDO and tensao != null:
		# A vara verga para o lado do peixe quando ele puxa.
		var lado := (_plano(posicao_da_boia) - _plano(j.global_position)).normalized()
		direcao = direcao.lerp(lado, clampf(tensao.tensao * 0.25, 0.0, 0.3))
	_visual.orientar(direcao, corpo.x)
	var boia_fora := estado in [Estado.ESPERANDO, Estado.MORDENDO, Estado.BRIGANDO, Estado.RECOLHENDO] \
		or (estado == Estado.ARREMESSANDO and _t >= SOLTA_A_BOIA)
	if not boia_fora:
		_visual.sem_linha()
		_visual.esconder_boia()
		return
	_visual.boia_em(posicao_da_boia)
	var folga := 0.7
	if estado == Estado.BRIGANDO and tensao != null:
		folga = 1.0 - tensao.tensao
	elif estado == Estado.ARREMESSANDO:
		folga = 0.15
	_visual.linha(posicao_da_boia + Vector3.UP * VaraDePescaVisual.RAIO_DA_BOIA * 0.6, folga)


# ------------------------------------------------------------------ estados
## Clique com a vara parada. Devolve false (com aviso) se não há água à frente.
func arremessar() -> bool:
	var j := _jogador()
	if j == null or estado != Estado.PARADO:
		return false
	var ponto := ponto_de_arremesso(j)
	if is_nan(ponto.x):
		aviso.emit("Mire na água para pescar (até %d m à frente)" % roundi(ALCANCE[0]))
		return false
	alvo = ponto
	_ir(Estado.ARREMESSANDO)
	AudioFX.whoosh(self, j.global_position + Vector3.UP, 1.3)
	return true


## O ponto da água mais longe à frente da câmera, ao alcance e sem parede no
## caminho. NAN se não há.
func ponto_de_arremesso(j: Node3D) -> Vector3:
	var frente := RosaDosVentos.frente(float(j.get("_yaw")))
	frente.y = 0.0
	frente = frente.normalized()
	var pes := j.global_position
	var espaco := j.get_world_3d().direct_space_state
	for d in ALCANCE:
		var p := pes + frente * d
		var nivel := AguaDoMundo.nivel_em(p.x, p.z)
		if is_nan(nivel) or nivel > pes.y + 1.0 or nivel < pes.y - 14.0:
			continue
		var agua := Vector3(p.x, nivel, p.z)
		var olho := pes + Vector3.UP * 1.6
		var raio := PhysicsRayQueryParameters3D.create(olho, agua + Vector3.UP * 0.3)
		raio.exclude = [(j as CollisionObject3D).get_rid()] if j is CollisionObject3D else []
		raio.collision_mask = ~HurtboxDeCombate.CAMADA & 0xFFFFFFFF
		if not espaco.intersect_ray(raio).is_empty():
			continue
		return agua
	return Vector3(NAN, NAN, NAN)


func _voar(j: Node3D) -> void:
	if _t < SOLTA_A_BOIA:
		posicao_da_boia = _visual.ponteira() if _visual.segurando() else j.global_position + Vector3.UP * 1.5
		_de = posicao_da_boia
		return
	var u := clampf((_t - SOLTA_A_BOIA) / (TEMPO_DO_ARREMESSO - SOLTA_A_BOIA), 0.0, 1.0)
	posicao_da_boia = _de.lerp(alvo, u) + Vector3.UP * sin(u * PI) * (2.0 + _de.distance_to(alvo) * 0.12)
	if u >= 1.0:
		_visual.respingo(alvo, 0.6)
		AudioFX.plop(self, alvo, 0.8)
		_comecar_espera()


func _comecar_espera() -> void:
	_ir(Estado.ESPERANDO)
	_espera = _rng.randf_range(ESPERA.x, ESPERA.y)
	_beliscadas.clear()
	for i in _rng.randi_range(0, 2):
		_beliscadas.append(_rng.randf_range(0.6, maxf(_espera - 0.5, 0.7)))
	_beliscada_ate = 0.0


func _esperar(apertou: bool) -> void:
	if apertou:
		aviso.emit("Cedo demais — linha recolhida")
		_recolher()
		return
	var y := _superficie(alvo) + sin(_t * 2.2) * 0.015
	for b in _beliscadas:
		if _t >= b and _t - get_physics_process_delta_time() < b:
			_beliscada_ate = _t + 0.16
			_visual.respingo(alvo, 0.2)
	if _t < _beliscada_ate:
		y -= 0.06
	posicao_da_boia = Vector3(alvo.x, y, alvo.z)
	if _t >= _espera:
		_ir(Estado.MORDENDO)
		_visual.respingo(alvo, 1.0)
		AudioFX.plop(self, alvo, 1.0)


func _fisgar() -> void:
	peixe_id = TabelaDePeixes.sortear(_rng, biblioteca)
	if peixe_id.is_empty():
		aviso.emit("Nenhum peixe na loja (categoria pesca)")
		_recolher()
		return
	var raridade := TabelaDePeixes.raridade(peixe_id)
	tensao = TensaoDaLinha.new(raridade, _rng.randi())
	_perto = _ponto_perto(_jogador())
	_respingo_em = 0.0
	_ir(Estado.BRIGANDO)
	aviso.emit("Fisgou um peixe %s!" % TabelaDePeixes.NOME_DA_RARIDADE[raridade])


func _brigar(j: Node3D, delta: float) -> void:
	var fim := tensao.passo(delta, _botao)
	var base := alvo.lerp(_perto, tensao.progresso)
	var lado := (alvo - _perto).cross(Vector3.UP).normalized()
	var balanco := sin(_t * 3.1) * 0.5 * (1.0 + float(tensao.correndo)) * minf(tensao.puxao() * 2.0, 1.0)
	var p := base + lado * balanco
	posicao_da_boia = Vector3(p.x, _superficie(p) - 0.2, p.z)
	_respingo_em -= delta
	if _respingo_em <= 0.0:
		_visual.respingo(posicao_da_boia + Vector3.UP * 0.2, 0.9 if tensao.correndo else 0.4)
		_respingo_em = 0.25 if tensao.correndo else 0.6
	match fim:
		TensaoDaLinha.Fim.PEGOU:
			var id := peixe_id
			progressao.guardar_item_de_pesca(id)
			_visual.peixe_saltando(id, posicao_da_boia, j.global_position + Vector3.UP * 1.3)
			AudioFX.plop(self, posicao_da_boia, 0.7)
			aviso.emit("Pescou: %s (%s)  ·  N › PESCA" % [TabelaDePeixes.nome(id), TabelaDePeixes.NOME_DA_RARIDADE[TabelaDePeixes.raridade(id)]])
			pescou.emit(id)
			_recolher()
		TensaoDaLinha.Fim.ARREBENTOU:
			aviso.emit("A linha arrebentou! O peixe %s fugiu" % TabelaDePeixes.NOME_DA_RARIDADE[tensao.raridade])
			AudioFX.snap(self, _visual.ponteira())
			_ir(Estado.PARADO)
		TensaoDaLinha.Fim.ESCAPOU:
			aviso.emit("O peixe escapou")
			_recolher()


func _recolher() -> void:
	_de = posicao_da_boia
	_ir(Estado.RECOLHENDO)


## Troca de item, nado, leme ou sela: recolhe sem aviso.
func _cancelar() -> void:
	_ir(Estado.PARADO)


func _ir(novo: Estado) -> void:
	estado = novo
	_t = 0.0
	if novo == Estado.PARADO:
		tensao = null
		peixe_id = ""


# ------------------------------------------------------------------ apoio
func _jogador() -> Node3D:
	return jogador_de.call() as Node3D if jogador_de.is_valid() else null


func _vara_na_mao(j: Node3D) -> bool:
	var c: Variant = j.get("capacidades")
	return c != null and bool(c.get("can_fish"))


func _corpo_livre(j: Node3D) -> bool:
	return str(j.get("modo_na_agua")) == "" and not j.get_meta("pilotando", false) \
		and not j.get_meta("montado", false)


func _mao(j: Node3D) -> Node3D:
	var rig: Variant = j.get("_rig")
	var mao: Variant = rig.get("item_handle") if rig != null else null
	return mao as Node3D if mao is Node3D and is_instance_valid(mao) else null


func _base_do_corpo(j: Node3D) -> Basis:
	var rig: Variant = j.get("_rig")
	var modelo: Node3D = rig.call("modelo") if rig != null else null
	var yaw := modelo.global_rotation.y if modelo != null else 0.0
	return Basis(Vector3.UP, yaw)


func _ler_botao() -> bool:
	if botao_forcado >= 0:
		return botao_forcado == 1
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("is_menu_open") and hud.is_menu_open():
		return false
	var mira := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or ToqueHud.ativo()
	return mira and Input.is_action_pressed(ACAO)


## Pose dos braços e frente do corpo (metas lidas pelo animador e pelo Player).
func _marcar_pose(j: Node3D, livre: bool) -> void:
	if j == null:
		return
	if not livre:
		for m in ["pesca_pose", "pesca_fase", "pesca_girando", "frente_forcada"]:
			if j.has_meta(m):
				j.remove_meta(m)
		return
	var pose := "segura"
	match estado:
		Estado.ARREMESSANDO:
			pose = "arremesso"
		Estado.BRIGANDO, Estado.RECOLHENDO:
			pose = "puxando"
	j.set_meta("pesca_pose", pose)
	j.set_meta("pesca_fase", clampf(_t / TEMPO_DO_ARREMESSO, 0.0, 1.0))
	j.set_meta("pesca_girando", _botao and estado in [Estado.BRIGANDO, Estado.RECOLHENDO])
	if ocupada():
		var para := (alvo - j.global_position) if estado == Estado.ARREMESSANDO else (posicao_da_boia - j.global_position)
		para.y = 0.0
		if para.length_squared() > 0.04:
			# Mesma conta de `LocomocaoChao.yaw_de` (frente = −Z).
			j.set_meta("frente_forcada", atan2(-para.x, -para.z))
	elif j.has_meta("frente_forcada"):
		j.remove_meta("frente_forcada")


## Onde a boia termina quando a barra enche: na água, o mais perto possível do
## jogador ao longo da linha (beira do rio / do mar).
func _ponto_perto(j: Node3D) -> Vector3:
	if j == null:
		return alvo
	var pes := _plano(j.global_position)
	var ultimo := alvo
	for i in range(1, 11):
		var p := alvo.lerp(Vector3(pes.x, alvo.y, pes.z), float(i) / 10.0 * 0.85)
		if is_nan(AguaDoMundo.nivel_em(p.x, p.z)):
			break
		ultimo = p
	return ultimo


func _superficie(p: Vector3) -> float:
	var y := AguaDoMundo.superficie_em(p.x, p.z)
	return y if not is_nan(y) else alvo.y


static func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
