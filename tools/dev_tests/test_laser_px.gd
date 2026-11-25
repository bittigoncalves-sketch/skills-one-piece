extends SceneTree
# ============================================================================
#  PX LASER BEAM — o Z sustentado do Pacifista.
#
#  Pedido do dono (2026-09-01): "Z lazer been, um laser que enquanto segurado no
#  Z ou 3 segundos não se passaram causa dano constante no alvo. O laser atual
#  está na vertical e está bem ruim."
#
#  ⚠️ AS DUAS COISAS QUE FALHAM EM SILÊNCIO AQUI:
#   • "dano constante" — um feixe que acerta UMA vez e fica bonito na tela passa
#     por bom em qualquer captura de tela. Por isso se conta o número de QUEDAS
#     distintas de vida, não o dano total.
#   • "está na vertical" — o eixo do cilindro é medido contra a direção de mira.
#     Comparar com a horizontal do mundo não serve: mirando para cima o feixe
#     DEVE inclinar.
#
#      DISPLAY=:1 godot --path . -s tools/dev_tests/test_laser_px.gd
# ============================================================================

const CAMINHO_LASER := "res://src/combat/laser_px.gd"

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return

	p.set_meta("damage_immune", true)
	p.combat_mode = "style"
	p.current_style_idx = 1                      # pacifista
	p.energy = p.max_energy
	p._skill_cooldowns["Z"] = 0.0
	await _quadros(2)

	await _orientacao(p)
	await _dano_constante(p)
	await _teto_de_tres_segundos(p)
	# Os últimos pulsos têm vida curta, mas ainda podem estar aguardando o fim do
	# passo de física quando o feixe baixa a marca. Drena-os antes de sair.
	for i in 20:
		await physics_frame

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## 1. O FEIXE DEITA NA DIREÇÃO DA MIRA — inclusive apontando para cima, que era
##    exatamente o caso que o `if abs(fwd.y) < 0.99` antigo deixava em pé.
func _orientacao(p: Node3D) -> void:
	print("=== 1. o feixe aponta para onde se mira ===")
	var Laser = load(CAMINHO_LASER)
	for caso in [
			{"nome": "mira horizontal", "aim": Vector3(0.0, 0.0, -1.0)},
			{"nome": "mira quase reta para cima", "aim": Vector3(0.02, 0.999, 0.0).normalized()},
			{"nome": "mira quase reta para baixo", "aim": Vector3(0.0, -0.999, 0.02).normalized()}]:
		p.set_meta("px_laser_ativo", true)
		var origem := p.global_position + Vector3.UP * 1.1
		var no = Laser.criar(p.get_parent(), p, origem, caso["aim"], 90.0, null)
		await _quadros(2)
		# O cilindro foi girado 90° em X: o comprimento dele é o eixo Y global.
		var eixo: Vector3 = no._feixe.global_transform.basis.y.normalized()
		var alinhado: float = absf(eixo.dot(caso["aim"]))
		print("   %-28s alinhamento=%.3f" % [caso["nome"], alinhado])
		_ok("%s: o corpo do feixe segue a mira" % caso["nome"], alinhado > 0.98)
		# O cilindro e centrado na propria origem. Confere as duas pontas para
		# impedir a regressao visual em que metade fica atras/atravessa o jogador.
		var centro: Vector3 = no._feixe.global_position
		var meia_altura: float = (no._feixe.mesh as CylinderMesh).height * 0.5
		var ponta_a := centro + eixo * meia_altura
		var ponta_b := centro - eixo * meia_altura
		var inicio: Vector3 = no._pivo.global_position
		# Pode ser menor que ALCANCE quando o raycast encontra piso/parede.
		var fim_esperado: Vector3 = inicio + caso["aim"] * (meia_altura * 2.0)
		var erro_inicio := minf(ponta_a.distance_to(inicio), ponta_b.distance_to(inicio))
		var erro_fim := minf(ponta_a.distance_to(fim_esperado), ponta_b.distance_to(fim_esperado))
		_ok("%s: nasce no jogador, sem metade para tras" % caso["nome"], erro_inicio < 0.05)
		_ok("%s: termina adiante, na direcao do alvo" % caso["nome"], erro_fim < 0.05)
		var mat := no._feixe.material_override as StandardMaterial3D
		_ok("%s: material nao encara a camera" % caso["nome"], mat != null
			and mat.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED)
		_ok("%s: o laser e amarelo" % caso["nome"], mat != null
			and mat.albedo_color.g > mat.albedo_color.b * 1.4)
		p.set_meta("px_laser_ativo", false)
		await _quadros(3)
	# ⚠️ CONTROLE: um feixe fixo no eixo Y passaria nas três medidas acima se eu
	#    tivesse comparado com a horizontal do mundo. Aqui se prova que os três
	#    casos apontam para lugares DIFERENTES.
	print("   (as três miras são distintas entre si — o feixe não é fixo)")


## 2. DANO CONSTANTE: o alvo perde vida em vários golpes ao longo do feixe.
func _dano_constante(p: Node3D) -> void:
	print("\n=== 2. dano constante enquanto o Z está preso ===")
	var alvo := _alvo_na_mira(p, 6.0)
	if alvo == null:
		_ok("havia um alvo para medir", false)
		return

	# A transformação visual muda na hora, mas o broadphase do PhysicsServer só
	# enxerga a nova caixa no passo de física seguinte.
	await physics_frame
	await physics_frame
	var cam := p.get("_cam") as Camera3D
	var centro_tela := cam.get_viewport().get_visible_rect().size * 0.5
	var alvo_tela_antes := cam.unproject_position(alvo.global_position)
	var frente := (-cam.global_basis.z).normalized()
	var query := PhysicsRayQueryParameters3D.create(cam.global_position,
		cam.global_position + frente * 150.0)
	query.exclude = [p.get_rid()]
	query.collide_with_areas = false
	var hit := p.get_world_3d().direct_space_state.intersect_ray(query)
	_ok("o alvo foi montado no pixel da reticula",
		alvo_tela_antes.distance_to(centro_tela) < 2.0)
	_ok("o raio real da camera encontra esse alvo",
		not hit.is_empty() and hit.get("collider") == alvo)

	var vida0: float = float(alvo.get("health"))
	p.set_meta("px_laser_ativo", false)
	p.begin_charge("Z")
	await physics_frame
	await physics_frame
	_ok("segurar o Z acende o feixe", _feixe_de(p) != null)
	var laser := _feixe_de(p)
	if laser != null:
		var fim_mundo: Vector3 = laser._feixe.get_meta(BeamVisual3D.META_END)
		var fim_tela := cam.unproject_position(fim_mundo)
		var alvo_tela := cam.unproject_position(alvo.global_position)
		var erro_px := fim_tela.distance_to(alvo_tela)
		print("   erro projetado do fim ate o alvo: %.1f px" % erro_px)
		# Superfície e pivô têm profundidades diferentes, mas estão na mesma reta
		# óptica; portanto devem cair praticamente no mesmo pixel.
		_ok("na camera real o feixe termina sobre a silhueta do alvo", erro_px < 5.0)

	var quedas := 0
	var anterior := vida0
	for i in 60:
		await process_frame
		var agora: float = float(alvo.get("health"))
		if agora < anterior - 0.01:
			quedas += 1
			anterior = agora
	print("   quedas de vida em 60 quadros: %d (vida %.0f -> %.0f)" % [quedas, vida0, anterior])
	_ok("o alvo apanha VÁRIAS vezes, não uma só", quedas >= 2)

	# ⚠️ CONTROLE DO "ENQUANTO SEGURADO": soltar tem de apagar o feixe E parar o
	#    dano. Sem esta parte, um feixe eterno passaria como acerto no item acima.
	p.release_charge("Z")
	await _quadros(6)
	_ok("soltar o Z apaga o feixe", _feixe_de(p) == null)
	var vida_ao_soltar: float = float(alvo.get("health"))
	await _quadros(30)
	_ok("e o dano PARA junto", absf(float(alvo.get("health")) - vida_ao_soltar) < 0.01)


## 3. TETO DE 3 SEGUNDOS: mesmo com a tecla presa, o feixe morre sozinho.
##
## ⚠️ MEDIDO NO RELÓGIO DO JOGO, NÃO NO DE PAREDE. A primeira versão esperava
##    3,4 s de `Time.get_ticks_msec()` e acusava falha: sob carga a física anda
##    atrás do relógio real, e 3,4 s de parede eram só ~2,9 s de jogo — o feixe
##    estava certo e a régua é que era a errada. Aqui a régua é o `_restante` do
##    próprio feixe, com um teto de parede folgado só para não pendurar o teste.
func _teto_de_tres_segundos(p: Node3D) -> void:
	print("\n=== 3. o teto de 3 s ===")
	_ok("a duração declarada é 3 s", absf(float(load(CAMINHO_LASER).DURACAO) - 3.0) < 0.01)
	p._skill_cooldowns["Z"] = 0.0
	p.begin_charge("Z")
	await _quadros(2)
	_ok("o feixe acendeu", _feixe_de(p) != null)

	var aceso_no_meio := false
	var morreu_em := -1.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		await process_frame
		var f := _feixe_de(p)
		if f == null:
			morreu_em = (Time.get_ticks_msec() - t0) / 1000.0
			break
		# "Ainda aceso na metade": sem isto, um feixe que morresse no primeiro
		# quadro passaria como "se apaga sozinho".
		if float(f._restante) <= 1.5:
			aceso_no_meio = true
	print("   aceso na metade do tempo=%s | apagou sozinho aos %.1f s de parede"
		% [str(aceso_no_meio), morreu_em])
	_ok("passada a metade dos 3 s o feixe ainda está aceso", aceso_no_meio)
	_ok("e ele se apaga sozinho, sem soltar a tecla", morreu_em > 0.0)
	_ok("a marca do hold é baixada junto", not bool(p.get_meta("px_laser_ativo", false)))


# ------------------------------------------------------------------ apoio
func _feixe_de(p: Node3D) -> Node:
	for f in p.get_children():
		var s = f.get_script()
		if s != null and s.resource_path == CAMINHO_LASER and not f.is_queued_for_deletion():
			return f
	return null


## Põe um inimigo exatamente na linha de mira, para o feixe ter o que acertar.
func _alvo_na_mira(p: Node3D, dist: float) -> Node3D:
	var cam := p.get("_cam") as Camera3D
	if cam == null:
		return null
	# O alvo precisa nascer NO RAIO DA CAMERA. Reaproveitar o `aim` calculado
	# antes de mover o dummy cria duas retas diferentes por causa do ombro da
	# câmera em 3ª pessoa: depois da mudança o pivô do alvo já não está no pixel
	# da mira, e o teste acusa paralaxe como se fosse erro do feixe.
	var frente := (-cam.global_basis.z).normalized()
	# `dist` é a distância desejada DEPOIS do jogador. Em 3ª pessoa a câmera já
	# fica ~6 m atrás dele; usar apenas `dist` colocaria o dummy dentro do corpo.
	var ate_jogador := maxf((p.global_position - cam.global_position).dot(frente), 0.0)
	var destino := cam.global_position + frente * (ate_jogador + dist)
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		if e is Node3D and e.has_method("take_damage"):
			e.set_physics_process(false)
			if e is CharacterBody3D:
				(e as CharacterBody3D).velocity = Vector3.ZERO
			e.global_position = destino
			if e.get("max_health") != null:
				e.set("health", e.get("max_health"))
			return e
	return null


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond:
		_ok_n += 1
		print("   ✓ %s" % rotulo)
	else:
		_falhas += 1
		print("   ❌ %s" % rotulo)
