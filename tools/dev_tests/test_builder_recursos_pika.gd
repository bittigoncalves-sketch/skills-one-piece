extends SceneTree
# ============================================================================
#  RECURSOS DO BUILDER PARA A PIKA REFEITA NO EDITOR (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_builder_recursos_pika.gd
#
#  O que o Z (feixe), o X (sobe + zigue-zague + esfera) e o C (barragem para o alvo)
#  pedem do editor, cada um provado com o JOGADOR de verdade (Modo História, mapa e
#  progresso de TESTE): teleporte e flutuar, ângulo lateral, Cometa (corpo vira luz),
#  hitbox que segue a mira e pára na parede, esfera para baixo que explode, mirar no
#  alvo (mesmo com ele ATRÁS) e "Sustentar" (soltar encerra).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const MAPA := "user://test_recursos_pika_mapa.json"
const PROGRESSO := "user://test_recursos_pika.json"

var _ok_n := 0
var _falhas := 0
var p: Node3D
var cena: Node


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await _fisica(120)
	cena = current_scene
	p = get_first_node_in_group("player")
	await _teleporte_e_flutuar()
	await _zigue_zague_e_cometa()
	await _feixe_pela_mira()
	await _esfera_que_explode()
	await _mirar_no_alvo_atras()
	await _sustentar()
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nRECURSOS_PIKA %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


# ------------------------------------------------------------------ casos

func _teleporte_e_flutuar() -> void:
	await _no_lugar(Vector3(0, 0.8, 0))
	var y0 := p.global_position.y
	var s := _skill(1.2, [_ev("sobe", "movimento", 0.0, 0.1, {"direcao": "Acima", "distancia": 6.0, "velocidade": 100.0, "teleporte": true})])
	s.configuracoes.flutuar = true
	_lancar(s)
	await _fisica(8)
	var subiu := p.global_position.y - y0
	await _fisica(42)
	var segue := p.global_position.y - y0
	_ok("teleporte para o alto: +%.2f m no primeiro quadro do bloco" % subiu, absf(subiu - 6.0) < 0.3)
	_ok("flutuar: 0,7 s depois continua lá (+%.2f m)" % segue, absf(segue - 6.0) < 0.3)
	await _fisica(90)
	_ok("acabou a skill: cai (+%.2f m)" % (p.global_position.y - y0), p.global_position.y - y0 < 1.0)


func _zigue_zague_e_cometa() -> void:
	await _no_lugar(Vector3(0, 0.8, 0))
	var de := p.global_position
	var s := _skill(0.5, [
		_ev("perna", "movimento", 0.0, 0.2, {"direcao": "Frente", "distancia": 8.0, "velocidade": 60.0, "angulo": -35.0, "curva": "Linear"}),
		_ev("luz", "vfx", 0.0, 0.3, {"estilo": "Cometa", "escala": 1.0, "altura": 0.8, "frente": 0.0})])
	s.configuracoes.flutuar = true
	_lancar(s)
	await _fisica(6)
	var modelo: Node3D = p.get("_char_model")
	var sumiu := not modelo.visible
	await _fisica(30)
	var d := p.global_position - de
	_ok("ângulo −35°: anda para a frente E para a esquerda (x %.2f, z %.2f; quer −4,6 / −6,5)" % [d.x, d.z],
		absf(d.x + 4.59) < 0.6 and absf(d.z + 6.55) < 0.6)
	_ok("Cometa: o corpo some enquanto o bloco dura (%s) e volta depois (%s)" % [sumiu, modelo.visible], sumiu and modelo.visible)


func _feixe_pela_mira() -> void:
	await _no_lugar(Vector3(0, 0.8, 0))
	var longe := _boneco(Vector3(0.6, 1.0, -24.0))
	var parede := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(3, 4, 0.5)
	cs.shape = caixa
	parede.add_child(cs)
	parede.position = Vector3(-3.75, 2.0, -10.0)    # na linha do jogador ao boneco (x = −6 × 10/16)
	cena.add_child(parede)
	var escondido := _boneco(Vector3(-6.0, 1.0, -16.0))
	await _fisica(10)
	var v_longe := float(longe.get("health"))
	var v_escondido := float(escondido.get("health"))
	var s := _skill(0.3, [_ev("feixe", "hitbox", 0.0, 0.15, {"forma": "Caixa", "largura": 0.8, "altura": 0.8, "profundidade": 40.0,
		"x": 0.0, "y": 1.3, "z": 0.0, "mirar": true, "unicos": true})])
	s.dano.valor = 200.0
	_lancar(s, longe.global_position)
	await _fisica(20)
	_ok("feixe pela mira acerta o boneco a 24 m (%.1f → %.1f)" % [v_longe, float(longe.get("health"))], float(longe.get("health")) < v_longe - 0.5)
	_lancar(s, escondido.global_position)
	await _fisica(20)
	_ok("e pára na parede: o boneco atrás dela não sofre (%.1f → %.1f)" % [v_escondido, float(escondido.get("health"))],
		is_equal_approx(float(escondido.get("health")), v_escondido))
	longe.queue_free()
	escondido.queue_free()
	parede.queue_free()
	await _fisica(3)


func _esfera_que_explode() -> void:
	await _no_lugar(Vector3(0, 6.8, 0))
	p.call("definir_flutuar", true)
	var perto := _boneco(Vector3(2.0, 1.0, 0.0))
	var longe := _boneco(Vector3(9.0, 1.0, 0.0))
	await _fisica(10)
	var v_perto := float(perto.get("health"))
	var v_longe := float(longe.get("health"))
	var s := _skill(1.5, [_ev("esfera", "projetil", 0.0, 0.1, {"velocidade": 18.0, "raio": 0.5, "quantidade": 1, "abertura": 0.0,
		"gravidade": 0.0, "vida": 3.0, "perfurar": false, "visual": "Energia", "rastro": "Brilho", "direcao_disparo": "Abaixo", "explosao": 4.0})])
	s.dano.valor = 160.0
	_lancar(s)
	await _fisica(70)
	p.call("definir_flutuar", false)
	_ok("esfera para baixo explode no chão: fere quem está a 2 m (%.1f → %.1f)" % [v_perto, float(perto.get("health"))], float(perto.get("health")) < v_perto - 0.5)
	_ok("…e não quem está a 9 m (%.1f → %.1f)" % [v_longe, float(longe.get("health"))], is_equal_approx(float(longe.get("health")), v_longe))
	perto.queue_free()
	longe.queue_free()
	await _fisica(60)


func _mirar_no_alvo_atras() -> void:
	await _no_lugar(Vector3(0, 0.8, 0))
	var atras := _boneco(Vector3(0.0, 1.0, 6.0))      # ATRÁS do jogador (ele olha para −Z)
	await _fisica(10)
	var vida := float(atras.get("health"))
	var s := _skill(0.3, [_ev("area", "hitbox", 0.0, 0.2, {"forma": "Caixa", "largura": 3.0, "altura": 3.0, "profundidade": 12.0,
		"x": 0.0, "y": 1.0, "z": 0.0, "mirar": true, "unicos": true})])
	s.dano.valor = 150.0
	s.configuracoes.mirar_no_alvo = true
	s.configuracoes.alcance = 20.0
	ExecutorDeSkill.lancar(p.call("_get_skills_container"), p, s, Vector3.FORWARD, 1.0, Vector3.INF)
	await _fisica(20)
	_ok("mirar no alvo: a skill vai para o boneco ATRÁS do jogador (%.1f → %.1f)" % [vida, float(atras.get("health"))], float(atras.get("health")) < vida - 0.5)
	atras.queue_free()
	await _fisica(3)


func _sustentar() -> void:
	await _no_lugar(Vector3(0, 0.8, 0))
	var s := _skill(2.0, [_ev("vfx", "vfx", 0.0, 2.0, {"estilo": "Fótons", "escala": 1.0})])
	s.ativacao.modo = "Sustentar"
	var e: ExecutorDeSkill = _lancar(s)
	await _fisica(30)
	var vivo := is_instance_valid(e)
	var r := e.soltar() if vivo else ""
	await _fisica(3)
	_ok("Sustentar: segurando segue (%s); soltar encerra na hora (%s, executor %s)" % [vivo, r, "vivo" if is_instance_valid(e) else "saiu"],
		vivo and r == "soltou" and not is_instance_valid(e))


# ------------------------------------------------------------------ apoio

func _skill(duracao: float, eventos: Array) -> Dictionary:
	var s := Dados.novo()
	s.eventos = eventos
	s.configuracoes.duracao = duracao
	s.condicoes.exige_alvo = false
	s.dano.empurrao = 0.0
	s.dano.atordoamento = 0.0
	var v := Dados.validar(s)
	if not v.ok:
		print("      skill de teste recusada: %s" % str(v.erros))
	return s


func _ev(id: String, tipo: String, inicio: float, duracao: float, params: Dictionary) -> Dictionary:
	return {"id": id, "tipo": tipo, "inicio": inicio, "duracao": duracao, "habilitado": true, "parametros": params}


func _lancar(s: Dictionary, mira := Vector3.INF) -> ExecutorDeSkill:
	var rumo := Vector3.FORWARD if not mira.is_finite() else (mira - p.global_position)
	return ExecutorDeSkill.lancar(p.call("_get_skills_container"), p, s, rumo, 1.0, mira)


func _boneco(pos: Vector3) -> Node3D:
	var b := BonecoDeDuelo.new()
	b.position = pos
	cena.add_child(b)
	b.set_deferred("modo", &"parado")
	return b


func _no_lugar(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.set("_yaw", 0.0)
	p.set("_pitch", 0.0)
	p.call("_update_pivot")
	await _fisica(12)
	for b in get_nodes_in_group("enemy"):
		if b is BonecoDeDuelo:
			b.call("parar")


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
