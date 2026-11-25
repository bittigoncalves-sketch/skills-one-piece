extends SceneTree
# ============================================================================
#  BARBA NEGRA, HABILIDADES DE AR, ENERGIA E CARANGUEJOS DA FOSSA (15/10/2026).
#    godot --headless --path . --script tools/dev_tests/test_barba_negra.gd
# ============================================================================

const PROGRESSO := "user://test_barba_negra.json"
const MAPA_VIVO := "res://mapas/historia/baseplate.json"

var _ok_n := 0
var _falhas := 0


## Corpo falso: o que o `DashNoAr` pede ao dono (capacidades, energia, gastar_energia).
class CorpoFalso extends CharacterBody3D:
	var capacidades := CapacidadesDoJogador.new()
	var energy := 100.0
	func gastar_energia(c: float) -> void:
		energy -= c


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	_progressao()
	_loja()
	_atributo_energia()
	await _dash_no_ar()
	await _crabs()
	await _npc_vivo()
	await _no_jogo()
	print("\nBARBA_NEGRA_RESULTADO ok=%d falhas=%d" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _progressao() -> void:
	print("— progressão")
	_ok("sem pontos por nível: atributos vêm do nível", not ("pontos" in ProgressaoDoPersonagem.new()))
	var p := ProgressaoDoPersonagem.new()
	_ok("começa sem pulo no ar nem dash", not p.desbloqueios["pulo_duplo"] and not p.desbloqueios["dash"])
	var c := p.capacidades()
	# Pulo e dash são do jogo, não do mod: 30 / 20 na proporção da energia de antes (100 por nível), escalados
	# pela energia do mod (27/10/2026): nível 1 = ×6.
	var f_custo := ProgressaoDoPersonagem.RegrasDosAtributos.fator_de_custo_fora_do_mod(p.nivel)
	_ok("capacidades: custos 30 / 20 × proporção da energia do mod (%.1f) e SEM recarga (20/11/2026)" % f_custo,
		is_equal_approx(c.custo_pulo_no_ar, 30.0 * f_custo) and is_equal_approx(c.custo_dash_no_ar, 20.0 * f_custo) and is_equal_approx(c.recarga_dash_no_ar, 0.0))
	_ok("preços: pulo no ar 10, dash 10 (20/11/2026)", ProgressaoDoPersonagem.preco_da_habilidade("pulo_duplo") == 10 and ProgressaoDoPersonagem.preco_da_habilidade("dash") == 10)
	p.ouro = 9
	_ok("9 moedas não compram o pulo", not p.comprar_habilidade("pulo_duplo", 10) and p.ouro == 9)
	p.ouro = 2500
	_ok("compra o pulo no ar (10)", p.comprar_habilidade("pulo_duplo", 10) and p.ouro == 2490 and p.capacidades().can_double_jump)
	_ok("pulo comprado = Geppo: sem teto de pulos, só a energia limita", p.capacidades().saltos_no_ar >= 999)
	_ok("não compra duas vezes", not p.comprar_habilidade("pulo_duplo", 10) and p.ouro == 2490)
	_ok("compra o dash no ar (10)", p.comprar_habilidade("dash", 10) and p.ouro == 2480 and p.capacidades().can_dash)
	_ok("não vende o que não é habilidade", not p.comprar_habilidade("bussola", 1))


func _loja() -> void:
	print("— loja do Barba Negra")
	var loja := load("res://src/historia/npcs/loja_do_barba_negra.gd").new() as LojaDeNpc
	var p := ProgressaoDoPersonagem.new()
	var l := loja.linhas(p, null)
	# Por preço: retirar (0), pulo e dash (10, empate pela ordem da lista), roleta (100).
	_ok("4 linhas por preço: retirar fruta (0), pulo no ar (10), dash no ar (10), roleta (100)", l.size() == 4 and l[0]["id"] == "retirar_fruta" and l[1]["id"] == "pulo_duplo" and l[2]["id"] == "dash" and l[3]["id"] == "roleta")
	_ok("sem fruta: Retirar desativado", not bool(l[0]["botoes"][0]["ativo"]))
	_ok("sem ouro: comprar desativado", not bool(l[1]["botoes"][0]["ativo"]) and not bool(l[2]["botoes"][0]["ativo"]))
	p.comer_fruta("rocket")
	p.ouro = 10
	l = loja.linhas(p, null)
	_ok("com fruta: Retirar ativo", bool(l[0]["botoes"][0]["ativo"]))
	var aviso := loja.executar(p, null, "retirar", "retirar_fruta")
	_ok("retira a fruta e ela se perde (%s)" % aviso, p.fruta.is_empty() and p.quantas_akuma("rocket") == 0 and not aviso.is_empty())
	_ok("retirar de novo: nada a retirar", p.fruta.is_empty() and loja.executar(p, null, "retirar", "retirar_fruta").begins_with("Você não"))
	aviso = loja.executar(p, null, "comprar", "dash")
	_ok("compra o dash pela loja (%s)" % aviso, bool(p.desbloqueios["dash"]) and p.ouro == 0)
	_ok("sem ouro: recusa o pulo", loja.executar(p, null, "comprar", "pulo_duplo").begins_with("Sem moedas") and not bool(p.desbloqueios["pulo_duplo"]))
	_ok("ficha do NPC existe, com o rig do personagem da arena",
		NpcDaIlha.ficha("npc_barba_negra").get("rig", "") == "blackbeard" and NpcDaIlha.ficha("npc_barba_negra").get("loja", "") == "res://src/historia/npcs/loja_do_barba_negra.gd")


func _atributo_energia() -> void:
	# 23/10/2026 (pedido do dono): energia por NÍVEL, 100 cada; o atributo Energia saiu.
	print("— energia por nível")
	var p := ProgressaoDoPersonagem.new()
	_ok("Energia não é mais atributo", not ProgressaoDoPersonagem.ATRIBUTOS.has("energia"))
	_ok("nível 1: 600 de energia, a do mod (cabe o pulo no ar)", p.energia_maxima() == 600 and p.energia_maxima() >= ProgressaoDoPersonagem.CUSTO_PULO_NO_AR)
	p.nivel = 3
	_ok("energia do mod: nível 3 = 200 × round(5 / 1,1) = 1000", p.energia_maxima() == 1000)
	for a in ProgressaoDoPersonagem.ATRIBUTOS:
		_ok("status explica '%s' na linha" % a, JanelaDeStatus.RESUMOS.has(a) and JanelaDeStatus.NOMES.has(a) and JanelaDeStatus.DICAS.has(a))


func _dash_no_ar() -> void:
	print("— dash no ar separado do roll")
	var cena := Node3D.new()
	root.add_child(cena)
	current_scene = cena
	var corpo := CorpoFalso.new()
	cena.add_child(corpo)
	await process_frame
	corpo.capacidades.can_dash = true
	corpo.capacidades.custo_dash_no_ar = 20.0
	corpo.capacidades.recarga_dash_no_ar = 0.1
	var ar := DashNoAr.new()
	ar.montar_em(corpo)
	var roll := DashController.new()
	roll.montar_em(corpo)
	var q := MoveFrame.new()
	q.dash_segurado = true
	_ok("corpo parado fora do chão (is_on_floor falso)", not corpo.is_on_floor())
	roll.atualizar(0.016, q, false)
	_ok("Q no ar NÃO faz o roll", not roll.ativo())
	ar.atualizar(0.016, q, false)
	_ok("Q no ar faz o dash no ar", ar.ativo() and ar.passo() > 0.0)
	_ok("custou 20 de energia", is_equal_approx(corpo.energy, 80.0))
	_ok("recarga de 0,1 s", ar.recarga() > 0.0 and ar.recarga() <= 0.1 + 0.001)
	q.dash_segurado = false
	for i in 20:
		ar.atualizar(0.016, q, false)
	_ok("dash acabou (0,28 s)", not ar.ativo())
	q.dash_segurado = true
	ar.atualizar(0.016, q, false)
	_ok("0,1 s depois do fim já dá de novo (recarga acabou)", ar.ativo() and is_equal_approx(corpo.energy, 60.0))
	q.dash_segurado = false
	for i in 25:
		ar.atualizar(0.016, q, false)
	corpo.energy = 19.0
	q.dash_segurado = true
	ar.atualizar(0.016, q, false)
	_ok("com 19 de energia NÃO dispara e não gasta", not ar.ativo() and is_equal_approx(corpo.energy, 19.0))
	q.dash_segurado = false
	ar.atualizar(0.016, q, false)
	corpo.energy = 100.0
	corpo.capacidades.can_dash = false
	q.dash_segurado = true
	ar.atualizar(0.016, q, false)
	_ok("sem a habilidade comprada NÃO dispara", not ar.ativo() and is_equal_approx(corpo.energy, 100.0))
	_ok("o roll não carrega mais constantes do dash no ar", not ("DASH_DISTANCIA" in DashController) and DashNoAr.TEMPO == 0.28)
	cena.queue_free()


func _crabs() -> void:
	print("— caranguejos gigantes da fossa")
	var lido := MapaArquivo.carregar(MAPA_VIVO)
	_ok("mapa vivo lê", lido["ok"])
	var mapa: Dictionary = lido["mapa"]
	var oc := load("res://src/world/oceano_historia.gd")
	var bases: Array = mapa["pecas"].filter(func(p: Dictionary) -> bool: return oc.e_base(p))
	var placas: Array[Rect2] = []
	for ilha in FundoDoMar.agrupar(bases):
		placas.append(FundoDoMar.caixa_de(ilha))
	var terrenos: Array = mapa["pecas"].filter(func(p: Dictionary) -> bool: return p.get("tipo") == "terreno")
	var relevo := RelevoMarinho.new()
	relevo.relevo_em = FundoDoMar._relevo_em.bind(terrenos)
	relevo.configurar(placas, FundoDoMar.ALCANCE, -0.65)
	var no := load("res://src/historia/mar/caranguejos_gigantes.gd").new() as Node3D
	root.add_child(no)
	no.relevo = relevo
	var total := 0
	var fora_da_fossa := 0
	var raso := 0
	var de := relevo.limite.position
	var ate := relevo.limite.end
	var blocos := 0
	for bx in range(floori(de.x / 64.0), ceili(ate.x / 64.0)):
		for bz in range(floori(de.y / 64.0), ceili(ate.y / 64.0)):
			blocos += 1
			var plano: Array = no.planejar(Vector2i(bx, bz))
			total += plano.size()
			if plano.size() > no.POR_BLOCO:
				_ok("no máximo %d por bloco" % no.POR_BLOCO, false)
			for c in plano:
				var pos: Vector3 = c["pos"]
				if relevo.altura(pos.x, pos.z) >= -70.0:
					fora_da_fossa += 1
	_ok("varreu %d blocos: há caranguejos (%d)" % [blocos, total], total > 0)
	_ok("NENHUM fora da fossa (fundo ≥ -70 m)", fora_da_fossa == 0)
	var igual := true
	for k in 3:
		var a: Array = no.planejar(Vector2i(2, -3))
		var b: Array = no.planejar(Vector2i(2, -3))
		igual = igual and a.size() == b.size()
	_ok("planejamento determinístico", igual)
	# Montagem de verdade: acha um bloco com caranguejo e instancia o modelo.
	no._bib = BibliotecaDeModelos.padrao()
	var achou := Vector2i.ZERO
	var tem := false
	for bx in range(floori(de.x / 64.0), ceili(ate.x / 64.0)):
		for bz in range(floori(de.y / 64.0), ceili(ate.y / 64.0)):
			if not tem and not (no.planejar(Vector2i(bx, bz)) as Array).is_empty():
				achou = Vector2i(bx, bz)
				tem = true
	if tem:
		no.montar_em_volta(Vector2(achou) * 64.0 + Vector2(32, 32), 10.0)
		_ok("montou %d caranguejo(s) com o modelo da loja" % no.quantos(), no.quantos() > 0)
		var y0: float = -1.0e9
		for c in no._blocos:
			for cr in no._blocos[c]:
				var n: Node3D = cr["no"]
				for k in 200:
					no._andar(cr, 0.05)
				y0 = n.global_position.y
				_ok("anda sem sair da fossa (y=%.1f)" % y0, relevo.altura(n.global_position.x, n.global_position.z) < -70.0)
				_ok("fica no fundo", absf(n.global_position.y - relevo.altura(n.global_position.x, n.global_position.z)) < 0.01)
	no.queue_free()


func _npc_vivo() -> void:
	print("— o NPC nasce com o modelo do Barba Negra")
	var cena := Node3D.new()
	root.add_child(cena)
	var npc := NpcDaIlha.new()
	npc.tipo = "npc_barba_negra"
	npc.biblioteca = BibliotecaDeModelos.padrao()
	cena.add_child(npc)
	for i in 5:
		await process_frame
	var modelo: Node3D = npc._rig.modelo()
	_ok("o rig montou o modelo do Barba Negra", modelo != null and npc._rig.character_id == "blackbeard")
	var aabb := PlayerModelKit.skeleton_aabb(modelo) if modelo != null else AABB()
	var altura := aabb.size.y * modelo.scale.y if modelo != null else 0.0
	_ok("1,5× maior que o jogador (altura %.2f m)" % altura, altura > 2.1 and altura < 2.4)
	var rotulo := npc.get_node("Nome") as Label3D
	_ok("rótulo \"Barba Negra\" acima da cabeça maior (y=%.2f)" % rotulo.position.y, rotulo.text == "Barba Negra" and rotulo.position.y > NpcDaIlha.ALTURA * 1.2)
	_ok("a loja dele é a do Barba Negra", npc.loja() != null and npc.loja().get_script().resource_path.ends_with("loja_do_barba_negra.gd"))
	cena.queue_free()


func _no_jogo() -> void:
	print("— no jogo (pulo no ar com energia)")
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	var j: Node3D = get_first_node_in_group("player")
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	_ok("jogador e progressão no ar", j != null and prog != null)
	if j == null or prog == null:
		return
	prog.desbloquear("pulo_duplo", true)
	prog.desbloquear("dash", true)
	await process_frame
	var pulo: float = 30.0 * ProgressaoDoPersonagem.RegrasDosAtributos.fator_de_custo_fora_do_mod(int(j.get_meta("nivel_historia", 1)))
	_ok("o corpo recebeu os custos (%.0f / dash)" % pulo, is_equal_approx(j.capacidades.custo_pulo_no_ar, pulo))
	var pk = j._parkour
	j.energy = pulo - 1.0
	_ok("1 a menos que o custo: NÃO paga o pulo no ar", not pk._pode_pagar_pulo_no_ar())
	j.energy = pulo
	_ok("o custo exato: paga", pk._pode_pagar_pulo_no_ar())
	pk._pagar_pulo_no_ar()
	_ok("gastou %.0f (sobrou %.1f)" % [pulo, j.energy], absf(j.energy) < 0.5)
	var s: Node = get_root().get_node("GameFlow")
	# Arena: sem custo.
	var arena := CapacidadesDoJogador.completas()
	_ok("arena: pulo e dash no ar de graça, recarga antiga", arena.custo_pulo_no_ar == 0.0 and arena.custo_dash_no_ar == 0.0 and arena.recarga_dash_no_ar == 1.5)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
