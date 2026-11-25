extends SceneTree
# ============================================================================
#  TESTE — cardumes (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E6).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_cardumes.gd
#
#  Lê o MAPA VIVO (só leitura). Confere: toda espécie dos tipos vira malha normalizada
#  (comprimento 1 em Z, sem esqueleto); onde cada tipo vive (recife na zona de recife,
#  fossa só no fundo, casa dentro d'água); o cardume vagueia perto de casa sem sair da
#  água; foge do jogador e se agita; determinístico; escondido fora d'água.
#  Controle: um cardume sem jogador perto NÃO se afasta como na fuga.
# ============================================================================

const Cardumes := preload("res://src/historia/mar/cardumes.gd")

var _falhas := 0


func _initialize() -> void:
	_executar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _executar() -> void:
	print("\n===== CARDUMES =====")
	var mapa: Dictionary = MapaArquivo.carregar("res://mapas/historia/baseplate.json")["mapa"]
	var oceano: Script = load("res://src/world/oceano_historia.gd")
	var bases: Array = mapa["pecas"].filter(func(p: Dictionary) -> bool: return oceano.e_base(p))
	var mundo := Node3D.new()
	root.add_child(mundo)
	var fundos := FundoDoMar.montar_por_ilha(mundo, mapa, bases, -0.65)
	var relevo: RelevoMarinho = fundos[0].relevo
	var c: Node3D = Cardumes.new()
	mundo.add_child(c)
	c.ligar({"bib": BibliotecaDeModelos.padrao()}, relevo, Callable())

	# Malhas normalizadas.
	var ruins := []
	var total_especies := 0
	for tipo in Cardumes.TIPOS:
		for especie in Cardumes.TIPOS[tipo]["especies"]:
			total_especies += 1
			var m: ArrayMesh = c.malha_de(especie)
			# Só comprimento e largura: o peixe-lua é mesmo mais ALTO que comprido.
			if m == null or absf(m.get_aabb().size.z - 1.0) > 0.01 or m.get_aabb().size.x > 1.0 \
					or m.surface_get_arrays(0)[Mesh.ARRAY_BONES] != null:
				ruins.append(especie)
	_ok(ruins.is_empty(), "%d espécies viram malha normalizada (comprimento 1 em Z, sem ossos) — ruins: %s" % [total_especies, ruins])

	# Onde cada tipo vive (plataforma e mar aberto em volta da ilha inicial).
	var por_tipo := {}
	var fora_dagua := 0
	var recife_fora := 0
	var fossa_raso := 0
	for bj in range(-12, 12, 2):
		for bi in range(-12, 13, 2):
			for plano in c.planejar(Vector2i(bi, bj)):
				por_tipo[plano["tipo"]] = int(por_tipo.get(plano["tipo"], 0)) + 1
				var casa: Vector3 = plano["casa"]
				var chao := relevo.altura(casa.x, casa.z)
				fora_dagua += int(casa.y <= chao or casa.y >= relevo.nivel)
				if String(plano["tipo"]).begins_with("recife"):
					recife_fora += int(relevo.recife(casa.x, casa.z) < 0.3)
				if plano["tipo"] == "fossa":
					fossa_raso += int(relevo.profundidade(casa.x, casa.z) < 70.0)
	print("     cardumes por tipo: %s" % por_tipo)
	# Amostra de 1 bloco em cada 4 (passo 2 nos dois eixos).
	_ok(int(por_tipo.get("recife", 0)) + int(por_tipo.get("recife_grande", 0)) > 15 and por_tipo.has("aberto"), "recife e mar aberto povoados")
	_ok(fora_dagua == 0, "toda casa de cardume dentro d'água (%d fora)" % fora_dagua)
	_ok(recife_fora == 0, "cardume de recife só na zona de recife (%d fora)" % recife_fora)
	_ok(fossa_raso == 0, "peixe de fossa só com mais de 70 m de água (%d raso)" % fossa_raso)
	var a: Array = c.planejar(Vector2i(5, 1))
	var b: Array = c.planejar(Vector2i(5, 1))
	_ok(a.size() == b.size() and (a.is_empty() or a[0]["casa"] == b[0]["casa"]), "determinístico")

	# Movimento: vaguear perto de casa, sempre na água.
	var cam := Camera3D.new()
	mundo.add_child(cam)
	c.set("camera_de", func() -> Camera3D: return cam)
	cam.global_position = Vector3(380, -6, 90)
	c.call("montar_em_volta", Vector2(380, 90), 70.0)
	var blocos: Dictionary = c.get("_blocos")
	var lista: Array = []
	for k in blocos:
		lista.append_array(blocos[k])
	_ok(lista.size() >= 3, "%d cardumes montados em volta do recife" % lista.size())
	if lista.is_empty():
		_fim(mundo)
		return
	var cardume: Dictionary = lista[0]
	var tipo: Dictionary = Cardumes.TIPOS[cardume["tipo"]]
	var maior := 0.0
	var saiu := false
	for i in 1800:                                   # 30 s a 60 Hz, sem jogador
		c.mover(cardume, 1.0 / 60.0, Vector3.INF)
		var p: Vector3 = (cardume["no"] as Node3D).global_position
		maior = maxf(maior, p.distance_to(cardume["casa"]))
		saiu = saiu or p.y >= relevo.nivel or p.y <= relevo.altura(p.x, p.z)
	_ok(maior < float(tipo["casa"]) * 1.6 + 3.0, "vagueia perto de casa: até %.1f m (raio %.0f)" % [maior, tipo["casa"]])
	_ok(not saiu, "não sai da água nem entra no fundo em 30 s")
	# Controle: 2 s sem jogador — anda pouco.
	var p0: Vector3 = (cardume["no"] as Node3D).global_position
	for i in 120:
		c.mover(cardume, 1.0 / 60.0, Vector3.INF)
	var calmo := (cardume["no"] as Node3D).global_position.distance_to(p0)
	# Fuga: jogador a 2 m.
	var p1: Vector3 = (cardume["no"] as Node3D).global_position
	var jogador := p1 + Vector3(2, 0, 0)
	var pico := 0.0
	for i in 120:
		c.mover(cardume, 1.0 / 60.0, jogador)
		pico = maxf(pico, float(cardume["agitacao"]))
	var fugiu := (cardume["no"] as Node3D).global_position.distance_to(jogador) - 2.0
	_ok(fugiu > 4.0 and fugiu > calmo * 1.5, "foge do jogador: +%.1f m em 2 s (calmo andou %.1f m)" % [fugiu, calmo])
	_ok(pico > 0.95, "agita na fuga (pico %.2f)" % pico)

	# Esconde fora d'água.
	await process_frame
	_ok(c.visible, "câmera submersa: cardumes desenhados")
	cam.global_position = Vector3(380, 3, 90)
	await process_frame
	_ok(not c.visible, "câmera fora d'água: cardumes escondidos")
	_fim(mundo)


func _fim(mundo: Node) -> void:
	mundo.queue_free()
	print("\nCARDUMES_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)
