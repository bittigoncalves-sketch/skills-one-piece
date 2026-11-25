extends SceneTree
# ============================================================================
#  TÉCNICA GEPPO (18/11/2026): vários pulos no ar e dash no ar sem recarga, ensinados pelo Mestre do Geppo.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_geppo.gd
#  Regras (progressão, loja, save), dash no ar encadeado SEM esperar e SEM gastar energia, e no jogo: o corpo recebe 5 pulos no ar de graça.
# ============================================================================
var _ok_n := 0
var _falhas := 0
class CorpoFalso extends CharacterBody3D:
	var capacidades := CapacidadesDoJogador.new()
	var energy := 100.0
	func gastar_energia(c: float) -> void:
		energy -= c
func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
func _init() -> void:
	_executar.call_deferred()
func _executar() -> void:
	await process_frame
	var p := ProgressaoDoPersonagem.new()
	_ok("começa sem o Geppo", not p.desbloqueios["geppo"] and not p.capacidades().geppo and p.capacidades().saltos_no_ar == -1)
	p.ouro = ProgressaoDoPersonagem.PRECO_DO_GEPPO - 1
	_ok("sem moedas suficientes não aprende", not p.aprender_geppo() and not p.desbloqueios["geppo"] and p.ouro == ProgressaoDoPersonagem.PRECO_DO_GEPPO - 1)
	p.ouro = ProgressaoDoPersonagem.PRECO_DO_GEPPO + 7
	_ok("aprende pelo preço e sobram 7 moedas", p.aprender_geppo() and p.ouro == 7 and p.desbloqueios["geppo"])
	_ok("não aprende duas vezes (não cobra de novo)", not p.aprender_geppo() and p.ouro == 7)
	var c := p.capacidades()
	_ok("capacidades: dash e pulo no ar liberados", c.geppo and c.can_dash and c.can_double_jump)
	_ok("%d pulos no ar" % ProgressaoDoPersonagem.SALTOS_DO_GEPPO, c.saltos_no_ar == ProgressaoDoPersonagem.SALTOS_DO_GEPPO and c.saltos_no_ar >= 3)
	_ok("pulo e dash no ar de graça e dash sem recarga", c.custo_pulo_no_ar == 0.0 and c.custo_dash_no_ar == 0.0 and c.recarga_dash_no_ar == 0.0)
	# vai e volta pelo save
	var caminho := "user://test_geppo.json"
	p.corpo = "masculino"
	p.salvar(caminho)
	var lido := ProgressaoDoPersonagem.carregar(caminho)
	_ok("o Geppo sobrevive ao save", bool(lido.desbloqueios["geppo"]) and lido.capacidades().saltos_no_ar == ProgressaoDoPersonagem.SALTOS_DO_GEPPO)
	# loja
	var Loja = load("res://src/historia/npcs/loja_do_mestre_geppo.gd")
	var loja = Loja.new()
	var q2 := ProgressaoDoPersonagem.new()
	q2.ouro = 10
	var l: Array = loja.linhas(q2, null)
	_ok("a loja tem uma linha com o preço e o botão travado sem moedas", l.size() == 1 and l[0]["preco"] == ProgressaoDoPersonagem.PRECO_DO_GEPPO and not l[0]["botoes"][0]["ativo"])
	_ok("sem moedas: recusa e avisa o preço", loja.executar(q2, null, "comprar", "geppo").begins_with("Sem moedas") and not q2.desbloqueios["geppo"])
	q2.ouro = ProgressaoDoPersonagem.PRECO_DO_GEPPO
	var aviso: String = loja.executar(q2, null, "comprar", "geppo")
	_ok("compra pela loja (%s)" % aviso, q2.desbloqueios["geppo"] and q2.ouro == 0)
	_ok("depois de aprendido: avisa e o botão fica 'Aprendida'", loja.executar(q2, null, "comprar", "geppo").begins_with("Você já") and loja.linhas(q2, null)[0]["botoes"][0]["texto"] == "Aprendida")
	_ok("o NPC existe com a loja certa", NpcDaIlha.FICHAS.has("npc_mestre_geppo") and NpcDaIlha.FICHAS["npc_mestre_geppo"]["loja"].ends_with("loja_do_mestre_geppo.gd"))
	# dash no ar encadeado, sem recarga e sem energia
	var cena := Node3D.new()
	root.add_child(cena)
	current_scene = cena
	var corpo := CorpoFalso.new()
	cena.add_child(corpo)
	await process_frame
	corpo.capacidades = p.capacidades()
	var ar := DashNoAr.new()
	ar.montar_em(corpo)
	var q := MoveFrame.new()
	var feitos := 0
	for i in 6:
		q.dash_segurado = true
		ar.atualizar(0.016, q, false)
		if ar.ativo():
			feitos += 1
		q.dash_segurado = false
		for k in 20:                       # 0,32 s: o dash (0,28 s) acaba; NENHUMA espera extra de recarga
			ar.atualizar(0.016, q, false)
	_ok("6 dashes no ar seguidos, só esperando o fim de cada um (%d feitos)" % feitos, feitos == 6)
	_ok("sem gastar energia (%.0f de 100)" % corpo.energy, is_equal_approx(corpo.energy, 100.0))
	corpo.energy = 0.0
	q.dash_segurado = true
	ar.atualizar(0.016, q, false)
	_ok("até com a energia zerada o dash sai", ar.ativo())
	# no jogo
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_geppo_jogo.json"))
	modo.set("progresso_forcado", "user://test_geppo_jogo.json")
	var pe := ProgressaoDoPersonagem.carregar("user://test_geppo_jogo.json")
	pe.corpo = "masculino"
	pe.salvar("user://test_geppo_jogo.json")
	get_root().get_node("GameFlow").start_story()
	for i in 200:
		await physics_frame
	var j: Node3D = get_first_node_in_group("player")
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	_ok("jogador e progressão no jogo", j != null and prog != null)
	if j != null and prog != null:
		var pk = j.get("_parkour")
		_ok("antes do Geppo: 0 pulos no ar", pk._limite_de_geppo() == 0)
		prog.ouro = ProgressaoDoPersonagem.PRECO_DO_GEPPO
		prog.aprender_geppo()
		for i in 10:
			await physics_frame
		_ok("com o Geppo: %d pulos no ar no corpo" % pk._limite_de_geppo(), pk._limite_de_geppo() == ProgressaoDoPersonagem.SALTOS_DO_GEPPO)
		j.energy = 0.0
		_ok("pulo no ar não pede energia (energia 0)", pk._pode_pagar_pulo_no_ar())
	print("\nGEPPO %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)
