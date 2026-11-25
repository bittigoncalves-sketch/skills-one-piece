extends SceneTree
# ============================================================================
#  ZOAN: TRANSFORMA, USA OS GOLPES DA FORMA E VOLTA (14/11/2026) — as 10 frutas Zoan (`minepiece:can_transform`) pelo
#  controlador do jogo: `transformar` → forma ≥ 1 (escala/SIZE do mod) → cada golpe da lista roda sem faltas novas da camada →
#  `transformar(true)` volta à forma 0 com escala 1.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_zoan_golpes_nas_formas.gd
# ============================================================================
const ZOAN := ["hito_hito_daibutsu", "inu_inu_wolf", "inu_inu_okuchi_no_makami", "neko_neko_leopard", "neko_neko_sabertiger",
	"ryu_ryu_brachiosaurus", "ryu_ryu_pachycephalosaurus", "ryu_ryu_pteranodon", "ushi_ushi_giraffe", "tori_tori_phoenix", "uo_uo_seiryu"]
const IGNORADAS := ["bloco:cavar_fora_de_ilha"]
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func rodar() -> void:
	MundoMinePiece.FATOR_DE_PROJETIL = 1.0
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_zoan_golpes.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	alvo.position = jogador.global_position + Vector3(0, 0, -4)
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 1000000.0
	await quadros(10)
	var mc := McEntidade.de(jogador)
	var so := OS.get_environment("ZOAN_ONLY")      # ex.: ZOAN_ONLY=neko_neko_sabertiger,ryu_ryu_pteranodon
	for id in ZOAN:
		if so != "" and not (id in so.split(",")):
			continue
		modo.equipar_fruta(jogador, "")
		await quadros(5)
		# A progressão manda no que o corpo carrega (`fruta_a_equipar`): sem registrar a fruta nela, um `mudou` qualquer
		# (conquista, inventário) re-equipa o estilo base e troca o controlador no meio do teste.
		var prog = ItensDoMod.progressao(self)
		if prog != null:
			prog.comer_fruta(id)
			prog.fruta_ativa = true
			prog.item_ativo = "fruta"
		modo.equipar_fruta(jogador, id)
		await quadros(10)
		var c = jogador.get_node_or_null("FrutaMinePiece")
		if c == null or not c.pode_transformar():
			ok(false, "%s: o controlador do mod aceita transformar" % id)
			continue
		mc.removeAllEffects()
		jogador.energy = jogador.max_energy
		c.transformar(false)
		await quadros(30)
		var forma: int = c.forma_atual()
		var h := mc.escala(&"height")
		ok(forma >= 1, "%s: transformou (forma %d, escala %.2f)" % [id, forma, h])
		var antes := Mc.pedidos_sem_implementacao.duplicate()
		var golpes: Array = c.estado_das_tecnicas()
		var feriu := 0
		for i in golpes.size():
			mc.removeAllEffects()
			jogador.energy = jogador.max_energy
			jogador.global_position = alvo.global_position + Vector3(0, 0.8, 4.0 * maxf(h, 1.0))
			jogador.velocity = Vector3.ZERO
			await quadros(5)
			for _i in 3:
				var mira: Vector3 = alvo.global_position + Vector3.UP - jogador._cam.global_position
				jogador._yaw = RosaDosVentos.yaw_para(Vector3(mira.x, 0, mira.z).normalized())
				jogador._pitch = asin(mira.normalized().y)
				jogador._update_pivot()
				await quadros(3)
			alvo.health = alvo.max_health
			c = jogador.get_node_or_null("FrutaMinePiece")      # o controlador pode ser refeito por um golpe (troca de forma/fruta)
			if c == null or not is_instance_valid(c):
				ok(false, "%s: o controlador sumiu no golpe %d" % [id, i])
				break
			c.selecao = i
			c.usar(true)
			await quadros(6)
			c.usar(false)
			await quadros(40)
			if alvo.max_health - alvo.health > 0.0:
				feriu += 1
		var novas := {}
		for k in Mc.pedidos_sem_implementacao:
			var d: int = Mc.pedidos_sem_implementacao[k] - int(antes.get(k, 0))
			if d > 0 and not (k in IGNORADAS):
				novas[k] = d
		ok(novas.is_empty(), "%s: %d golpes da forma rodaram sem faltas novas, %d feriram %s" % [id, golpes.size(), feriu, str(novas)])
		mc.removeAllEffects()
		mc.getPersistentData().putDouble("skill", 0.0)
		await quadros(10)         # `ativo` do controlador é recalculado por quadro
		c = jogador.get_node_or_null("FrutaMinePiece")
		if c == null:
			ok(false, "%s: sem controlador para voltar" % id)
			continue
		if not c.has_method("transformar"):
			var nomes := []
			for f in jogador.get_children():
				if "Fruta" in str(f.name) or "fruta" in str(f.name):
					nomes.append("%s:%s:%s" % [f.name, f.get_script().resource_path.get_file(), str(f.get("fruta_id"))])
			ok(false, "%s: o controlador virou o antigo (%s) — filhos: %s" % [id, c.get_script().resource_path, str(nomes)])
			continue
		c.transformar(true)
		await quadros(30)
		ok(c.forma_atual() == 0 and absf(mc.escala(&"height") - 1.0) < 0.01, "%s: voltou à forma 0 (escala %.2f)" % [id, mc.escala(&"height")])
	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
