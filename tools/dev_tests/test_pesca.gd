extends SceneTree
# ============================================================================
#  PESCA — minigame da tensão da linha, vara na mão e barra de itens (03/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_pesca.gd
#
#  Pedido do dono: minigame de pesca, vara equipável no N, item ativo pela barra
#  1–6. Decisão: "Tensão da linha" (segurar recolhe, soltar dá linha, zona verde
#  enche a captura, linha arrebenta no limite, peixe raro puxa mais forte).
#
#  A — lógica pura (`TensaoDaLinha`, `TabelaDePeixes`): robôs jogando por sementes
#      fixas — o que solta no aviso pega todos; sempre segurar arrebenta; nunca
#      segurar deixa escapar; o lendário pune quem ignora o aviso.
#  B — no jogo (mapa plano + mar, progresso de TESTE): equipar no N, vara na mão
#      com a mão À FRENTE do ombro (convenção +X, docs/erros.md 03/10), arremesso
#      na água, cedo demais, mordida perdida, briga ganha (peixe no inventário e no
#      save), linha arrebentada, trocar de item recolhe, sem água não arremessa.
# ============================================================================

const DT := 1.0 / 60.0
const PROGRESSO := "user://test_pesca.json"

var _ok_n := 0
var _falhas := 0
var p: Node3D
var pesca: Pescaria
var prog: ProgressaoDoPersonagem
var hud: HistoriaHud
var avisos: Array[String] = []


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	print("\n===== A: lógica =====")
	_logica_da_tensao()
	_tabela()
	print("\n===== B: no jogo =====")
	await _no_jogo()
	print("\nPESCA %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


# ------------------------------------------------------------------ A
func _logica_da_tensao() -> void:
	for r: String in TensaoDaLinha.RARIDADES:
		var esperto := _jogar(r, "esperto")
		var sempre := _jogar(r, "sempre")
		var nunca := _jogar(r, "nunca")
		_ok("%s: soltando no aviso pega %d/30 (média %.1f s)" % [r, esperto["PEGOU"], esperto["tempo"]],
			esperto["PEGOU"] == 30 and esperto["tempo"] > 3.5 and esperto["tempo"] < 16.0)
		_ok("%s: sempre segurando arrebenta %d/30" % [r, sempre["ARREBENTOU"]], sempre["ARREBENTOU"] == 30)
		_ok("%s: nunca segurando o peixe escapa %d/30" % [r, nunca["ESCAPOU"]], nunca["ESCAPOU"] == 30)
	var ingenuo := _jogar("lendario", "ingenuo")
	_ok("lendário: ignorar o aviso de corrida arrebenta a linha (%d/30 arrebentou)" % ingenuo["ARREBENTOU"],
		ingenuo["ARREBENTOU"] >= 8)
	var comum := _jogar("comum", "esperto")
	var lendario := _jogar("lendario", "esperto")
	_ok("raro puxa mais: lendário leva mais que o comum (%.1f s × %.1f s)" % [lendario["tempo"], comum["tempo"]],
		lendario["tempo"] > comum["tempo"] * 1.6)


## Robôs com 0,2 s de reação. esperto: mantém a tensão no meio do verde e solta no
## aviso; ingenuo: mantém no meio e ignora o aviso; sempre/nunca: o nome diz.
func _jogar(raridade: String, robo: String) -> Dictionary:
	var res := {"PEGOU": 0, "ARREBENTOU": 0, "ESCAPOU": 0, "NENHUM": 0, "tempo": 0.0}
	for s in 30:
		var l := TensaoDaLinha.new(raridade, 1000 + s)
		var hist: Array = []
		var seg := false
		var t := 0.0
		while l.fim == TensaoDaLinha.Fim.NENHUM and t < 60.0:
			hist.append([l.tensao, l.avisando or l.correndo])
			seg = _decidir(robo, hist[maxi(hist.size() - 13, 0)], seg)
			l.passo(DT, seg)
			t += DT
		res[TensaoDaLinha.Fim.keys()[l.fim]] += 1
		res["tempo"] += t / 30.0
	return res


func _decidir(robo: String, obs: Array, seg: bool) -> bool:
	match robo:
		"sempre":
			return true
		"nunca":
			return false
		"esperto":
			if obs[1]:
				return false
	if obs[0] < 0.48:
		return true
	if obs[0] > 0.6:
		return false
	return seg


func _tabela() -> void:
	var bib := MapaMontador.biblioteca_em_uso()
	var faltando: Array[String] = []
	for id: String in TabelaDePeixes.PEIXES:
		if not bib.tem(id) or not bib.categorias_do_modelo(id).has("pesca"):
			faltando.append(id)
	_ok("todo peixe da tabela é um modelo da categoria pesca da loja (faltando: %s)" % str(faltando), faltando.is_empty())
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var conta := {}
	var N := 20000
	for i in N:
		var id := TabelaDePeixes.sortear(rng, bib)
		var r := TabelaDePeixes.raridade(id)
		conta[r] = int(conta.get(r, 0)) + 1
	var linha := []
	var perto := true
	for r: String in TabelaDePeixes.CHANCE:
		var pct := 100.0 * int(conta.get(r, 0)) / N
		linha.append("%s %.1f%%" % [r, pct])
		perto = perto and absf(pct - float(TabelaDePeixes.CHANCE[r])) < 1.5
	_ok("sorteio segue a chance por raridade (%s)" % ", ".join(linha), perto)


# ------------------------------------------------------------------ B
func _no_jogo() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	var cena := current_scene
	pesca = cena.get("_pesca")
	prog = cena.get("progressao")
	hud = cena.get("_hud")
	if p == null or pesca == null or prog == null or hud == null:
		_ok("cena da história montada (jogador, pesca, progresso, HUD)", false)
		return
	p.set_meta("damage_immune", true)
	pesca.semear(11)
	pesca.aviso.connect(func(t: String): avisos.append(t))

	# --- sem vara
	_ok("sem a vara: barra só com a luta %s, sem pescar" % str(hud.barra().itens()),
		hud.barra().itens() == (["luta"] as Array[String]) and not p.capacidades.can_fish and not pesca.visual().segurando())
	_ok("N: equipar sem ter a vara não faz nada", not hud.inventario().equipar_vara(true))

	# --- ganhar e equipar no N
	prog.ganhar_equipamento("vara_de_pesca")
	hud.alternar_inventario()
	hud.inventario().mostrar_aba("pesca")
	await process_frame
	_ok("N › PESCA mostra a vara com o botão Equipar", hud.inventario().find_child("BotaoVara", true, false) != null)
	_ok("N: Equipar põe a vara na barra, já ATIVA", hud.inventario().equipar_vara(true)
		and hud.barra().itens() == (["luta", "vara"] as Array[String]) and prog.item_em_uso() == "vara")
	hud.alternar_inventario()
	for i in 10:
		await physics_frame
	_ok("vara ativa: pesca liberada e soco travado (can_fish %s, can_attack %s)" % [p.capacidades.can_fish, p.capacidades.can_attack],
		p.capacidades.can_fish and not p.capacidades.can_attack)
	var mao: Node3D = p.get("_rig").item_handle
	_ok("a vara está na mão direita (item_handle)", pesca.visual().segurando() and pesca.visual().vara().get_parent() == mao)

	# --- na beira do mar, olhando para fora (+X)
	p.global_position = Vector3(250.0, 1.0, 0.0)
	p.velocity = Vector3.ZERO
	p.set("_yaw", -PI * 0.5)
	for i in 40:
		await physics_frame
	await _medir_pose("segura")

	# --- arremesso
	avisos.clear()
	var subiu := -INF
	await _clique()
	_ok("clique arremessa (estado %s)" % _nome(), pesca.estado == Pescaria.Estado.ARREMESSANDO)
	var ombro := _no_modelo(_papel("UpperArm_R"))
	for i in 60:
		await physics_frame
		if pesca.estado == Pescaria.Estado.ARREMESSANDO:
			subiu = maxf(subiu, _no_modelo(mao).y - ombro.y)
	_ok("no arremesso a mão passa por cima do ombro (%.2f m acima)" % subiu, subiu > 0.15)
	_ok("a boia caiu e espera (estado %s)" % _nome(), pesca.estado == Pescaria.Estado.ESPERANDO)
	var b := pesca.posicao_da_boia
	var dist := Vector2(b.x - p.global_position.x, b.z - p.global_position.z).length()
	var agua := AguaDoMundo.superficie_em(b.x, b.z)
	_ok("boia na água à frente: %.1f m, %.2f m da superfície" % [dist, b.y - agua],
		b.x > 256.0 and dist >= 4.0 and dist <= 15.0 and absf(b.y - agua) < 0.1)
	_ok("linha desenhada da ponteira até a boia", pesca.visual().boia().visible and _tem_linha())
	for i in 20:
		await physics_frame
	# O modelo é escalado para caber no corpo (~0,76): a base precisa ser normalizada.
	var frente: Vector3 = -(p.get("_rig").modelo() as Node3D).global_basis.orthonormalized().z
	var para := (pesca.posicao_da_boia - p.global_position)
	para.y = 0
	_ok("o corpo vira para a boia (%.2f)" % frente.dot(para.normalized()), frente.dot(para.normalized()) > 0.9)
	await _medir_pose("esperando")

	# --- cedo demais
	await _clique()
	await _esperar_estado(Pescaria.Estado.PARADO, 1.0)
	_ok("clicar antes da mordida recolhe (%s)" % str(avisos), pesca.estado == Pescaria.Estado.PARADO and _avisou("Cedo"))
	_ok("recolhida: sem boia nem linha", not pesca.visual().boia().visible and not _tem_linha())

	# --- mordida perdida
	avisos.clear()
	await _clique()
	await _esperar_estado(Pescaria.Estado.MORDENDO, 8.0)
	await physics_frame
	var fundo := AguaDoMundo.superficie_em(pesca.alvo.x, pesca.alvo.z) - pesca.posicao_da_boia.y
	_ok("a mordida afunda a boia (%.2f m abaixo da superfície)" % fundo, pesca.estado == Pescaria.Estado.MORDENDO and fundo > 0.1)
	await _esperar_estado(Pescaria.Estado.ESPERANDO, 1.5)
	_ok("sem clicar na janela: o peixe solta a isca e a espera recomeça", pesca.estado == Pescaria.Estado.ESPERANDO and _avisou("soltou"))

	# --- briga ganha
	await _esperar_estado(Pescaria.Estado.MORDENDO, 8.0)
	await _clique()
	_ok("clique na mordida fisga (estado %s, peixe %s)" % [_nome(), pesca.peixe_id], pesca.estado == Pescaria.Estado.BRIGANDO and TabelaDePeixes.eh_peixe(pesca.peixe_id))
	var peixe := pesca.peixe_id
	await physics_frame
	await process_frame
	var medidor := hud.find_child("PescaHud", true, false) as Control
	_ok("o medidor de tensão aparece na briga", medidor != null and medidor.visible)
	await _medir_pose("puxando")
	var antes := int(prog.pesca.get(peixe, 0))
	var segurou := false
	var t := 0.0
	while pesca.estado == Pescaria.Estado.BRIGANDO and t < 40.0:
		var l := pesca.tensao
		if l != null:
			segurou = false if (l.avisando or l.correndo) else (true if l.tensao < 0.48 else (false if l.tensao > 0.6 else segurou))
		pesca.botao_forcado = 1 if segurou else 0
		await physics_frame
		t += DT
	pesca.botao_forcado = 0
	_ok("briga ganha em %.1f s: %s (%s) foi para o inventário" % [t, TabelaDePeixes.nome(peixe), TabelaDePeixes.raridade(peixe)],
		int(prog.pesca.get(peixe, 0)) == antes + 1 and _avisou("Pescou"))
	_ok("o peixe salta para a mão", pesca.visual().find_child("PeixeSaltando", true, false) != null)
	await _esperar_estado(Pescaria.Estado.PARADO, 1.0)

	# --- linha arrebentada
	avisos.clear()
	await _clique()
	await _esperar_estado(Pescaria.Estado.MORDENDO, 8.0)
	await _clique()
	pesca.botao_forcado = 1
	await _esperar_estado(Pescaria.Estado.PARADO, 4.0)
	pesca.botao_forcado = 0
	_ok("segurando sem parar a linha arrebenta (%s)" % str(avisos), pesca.estado == Pescaria.Estado.PARADO and _avisou("arrebentou"))

	# --- trocar de item recolhe
	await _clique()
	await _esperar_estado(Pescaria.Estado.ESPERANDO, 1.5)
	var quadro := hud.barra().itens().find("vara")
	hud.barra().escolher(quadro)   # 19/11/2026: o mesmo número de novo NÃO solta a vara
	_ok("tecla da vara de novo mantém a vara ativa", prog.item_em_uso() == "vara")
	hud.barra().escolher(hud.barra().itens().find("luta"))   # trocar de slot é que recolhe (volta à luta)
	for i in 6:
		await physics_frame
	await process_frame
	_ok("trocar para a luta: linha recolhida e vara fora da mão",
		prog.item_em_uso() == "luta" and pesca.estado == Pescaria.Estado.PARADO and not pesca.visual().segurando()
		and not p.has_meta("pesca_pose") and not p.has_meta("frente_forcada") and p.capacidades.can_attack)
	hud.barra().escolher(quadro)
	for i in 6:
		await physics_frame

	# --- sem água à frente
	avisos.clear()
	p.global_position = Vector3(0.0, 1.0, 0.0)
	p.set("_yaw", PI * 0.5)
	for i in 10:
		await physics_frame
	_ok("sem água à frente não arremessa e avisa (%s)" % str(avisos), not pesca.arremessar() and _avisou("Mire na água"))

	# --- save
	var lido := ProgressaoDoPersonagem.carregar(PROGRESSO)
	_ok("save guarda peixe, vara e equipada (%s)" % str(lido.pesca),
		int(lido.pesca.get(peixe, 0)) == int(prog.pesca.get(peixe, 0)) and lido.equipamentos.has("vara_de_pesca") and lido.vara_equipada)
	hud.alternar_inventario()
	hud.inventario().mostrar_aba("pesca")
	await process_frame
	var achou := false
	for rotulo in hud.inventario().find_children("*", "Label", true, false):
		achou = achou or (rotulo as Label).text == TabelaDePeixes.nome(peixe)
	_ok("N › PESCA lista o peixe pelo nome (%s)" % TabelaDePeixes.nome(peixe), achou)
	hud.alternar_inventario()
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")


## Mão × ombro no espaço do MODELO (frente = −Z). Uma linha por pose.
func _medir_pose(rotulo: String) -> void:
	var mao: Node3D = p.get("_rig").item_handle
	var m := _no_modelo(mao)
	var o := _no_modelo(_papel("UpperArm_R"))
	var ponta := (p.get("_rig").modelo() as Node3D).to_local(pesca.visual().ponteira())
	print("   · %s: mão (%.2f, %.2f, %.2f)  ombro (%.2f, %.2f, %.2f)  ponteira (%.2f, %.2f, %.2f)" % [rotulo, m.x, m.y, m.z, o.x, o.y, o.z, ponta.x, ponta.y, ponta.z])
	_ok("%s: mão À FRENTE do ombro (%.2f m) e abaixo dele" % [rotulo, o.z - m.z], m.z < o.z - 0.15 and m.y < o.y + 0.05)
	_ok("%s: ponteira à frente e acima da mão" % rotulo, ponta.z < m.z - 0.7 and ponta.y > m.y + 0.5)


func _papel(nome: String) -> Node3D:
	return p.get("_rig").procedural()._n[nome]


func _no_modelo(n: Node3D) -> Vector3:
	return (p.get("_rig").modelo() as Node3D).to_local(n.global_position)


func _tem_linha() -> bool:
	return (pesca.visual()._malha as ImmediateMesh).get_surface_count() > 0


func _clique() -> void:
	pesca.botao_forcado = 1
	await physics_frame
	await physics_frame
	pesca.botao_forcado = 0
	await physics_frame


func _esperar_estado(e: Pescaria.Estado, teto: float) -> void:
	var t := 0.0
	while pesca.estado != e and t < teto:
		await physics_frame
		t += DT


func _avisou(trecho: String) -> bool:
	for a in avisos:
		if trecho in a:
			return true
	return false


func _nome() -> String:
	return Pescaria.Estado.keys()[pesca.estado]


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
