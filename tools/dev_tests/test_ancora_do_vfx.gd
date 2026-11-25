extends SceneTree
# ============================================================================
#  ÂNCORA DO VFX NO SKILLS BUILDER — jogo e prévia (07/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_ancora_do_vfx.gd
#
#  Pedido do dono: "adicionar a opção de selecionar onde uma skill VFX tem sua âncora
#  inicial, começando por player até qualquer objeto, animação ou projétil na cena,
#  podendo até ser no inimigo". Uma skill com um projétil ("bola") e um VFX por âncora;
#  no meio dela, cada VFX tem de estar onde a âncora diz:
#    Jogador (segue o pé + Altura/À frente), Osso (cabeça), Alvo (boneco), Projétil (a
#    bola), Ponto mirado, Mundo (fica onde nasceu quando o jogador sai do lugar).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const ANCORAS := {"v_jogador": {"ancora": "Jogador"}, "v_osso": {"ancora": "Osso do jogador", "osso": "Cabeça"},
	"v_alvo": {"ancora": "Alvo"}, "v_bola": {"ancora": "Projétil", "projetil_de": "bola"},
	"v_mira": {"ancora": "Ponto mirado"}, "v_mundo": {"ancora": "Mundo"}}

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var s := _skill()
	var v := Dados.validar(s)
	_ok("a skill com as seis âncoras é válida (%s)" % str(v.erros), bool(v.ok))

	# --- jogo
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_ancora_do_vfx.json")
	root.get_node("GameFlow").start_story()
	await _fisica(150)
	var p: Node3D = get_first_node_in_group("player")
	p.global_position = Vector3(0, 0.8, 0)
	var boneco := BonecoDeDuelo.new()
	boneco.position = Vector3(3.0, 1.0, -7.0)
	current_scene.add_child(boneco)
	await _fisica(30)
	boneco.call("parar")
	var mira := Vector3(-2.0, 0.5, -9.0)
	var e := ExecutorDeSkill.lancar(p.call("_get_skills_container"), p, s, Vector3.FORWARD, 1.0, mira)
	while is_instance_valid(e) and float(e.get("_t")) < 0.3:
		await physics_frame
	var mundo0 := _vfx(e, "v_mundo")
	p.global_position += Vector3(3.0, 0.0, 0.0)          # o jogador sai do lugar
	await _fisica(6)
	var cabeca := p.find_child("Head", true, false) as Node3D
	var bola := Vector3.INF
	for m in e.get("_manuais"):
		if str(m.get("bloco", "")) == "bola" and is_instance_valid(m.no):
			bola = (m.no as Node3D).global_position
	var pe: Vector3 = e.call("pe")
	_perto("jogo, Jogador: segue o pé (+ Altura 1 / À frente 1)", _vfx(e, "v_jogador"), pe + Vector3(0, 1, -1), 0.15)
	_perto("jogo, Osso (cabeça)", _vfx(e, "v_osso"), cabeca.global_position if cabeca else Vector3.INF, 0.05)
	_perto("jogo, Alvo (o boneco)", _vfx(e, "v_alvo"), AlvosDeGolpe.centro(boneco), 0.05)
	_perto("jogo, Projétil (a bola)", _vfx(e, "v_bola"), bola, 0.05)
	_perto("jogo, Ponto mirado", _vfx(e, "v_mira"), mira, 0.01)
	_perto("jogo, Mundo: ficou onde nasceu com o jogador 3 m ao lado", _vfx(e, "v_mundo"), mundo0, 0.01)
	await _fisica(60)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")

	# --- prévia
	root.get_node("GameFlow").start_skills_builder()
	await _quadros(60)
	var ed := current_scene
	ed.call("_documento", s)
	await _quadros(5)
	var arena: Node = ed.get("arena")
	arena.call("buscar", 0.4)
	await _quadros(2)
	var eventos: Dictionary = arena.get("_eventos")
	var alvo: Node3D = arena.get("alvo")
	var modelo: Node3D = arena.get("modelo")
	var bola_p := Vector3.INF
	for pr in arena.get("_projeteis"):
		if str(pr.id).begins_with("bola:") and not pr.morto:
			bola_p = (pr.node as Node3D).global_position
	var cab_p := modelo.find_child("Head", true, false) as Node3D
	_perto("prévia, Osso (cabeça)", _no(eventos, "v_osso"), cab_p.global_position if cab_p else Vector3.INF, 0.05)
	_perto("prévia, Alvo (o alvo de treino)", _no(eventos, "v_alvo"), alvo.global_position + Vector3.UP, 0.05)
	_perto("prévia, Projétil (a bola)", _no(eventos, "v_bola"), bola_p, 0.05)
	print("\nANCORA_DO_VFX %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _skill() -> Dictionary:
	var s := Dados.novo()
	s.identificacao.id = "teste_ancora"
	s.configuracoes.duracao = 1.0
	s.configuracoes.custo = 0.0
	s.condicoes.exige_alvo = false
	var eventos := [{"id": "bola", "tipo": "projetil", "inicio": 0.0, "duracao": 0.1, "habilitado": true,
		"parametros": {"velocidade": 8.0, "vida": 2.0, "quantidade": 1, "abertura": 0.0, "gravidade": 0.0,
		"sem_dano": true, "direcao_disparo": "Frente"}}]
	for id in ANCORAS:
		var p: Dictionary = {"estilo": "Anel", "escala": 0.5}
		p.merge(ANCORAS[id], true)
		eventos.append({"id": id, "tipo": "vfx", "inicio": 0.05, "duracao": 0.9, "habilitado": true, "parametros": p})
	s.eventos = eventos
	return s


func _vfx(e: Node, id: String) -> Vector3:
	if not is_instance_valid(e):
		return Vector3.INF
	var st: Dictionary = (e.get("_estado") as Dictionary).get(id, {})
	return (st.no as Node3D).global_position if st.has("no") and is_instance_valid(st.no) and (st.no as Node3D).visible else Vector3.INF


func _no(eventos: Dictionary, id: String) -> Vector3:
	var st: Dictionary = eventos.get(id, {})
	return (st.node as Node3D).global_position if st.has("node") and (st.node as Node3D).visible else Vector3.INF


func _perto(rotulo: String, a: Vector3, b: Vector3, tolerancia: float) -> void:
	var d := a.distance_to(b) if a.is_finite() and b.is_finite() else INF
	_ok("%s (%.3f m)" % [rotulo, d], d <= tolerancia)


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
