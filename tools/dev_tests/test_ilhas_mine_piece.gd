extends SceneTree
# ============================================================================
#  ILHAS DAS ESTRUTURAS DO MINE PIECE (18/10/2026, docs/ESTRUTURAS_MINE_PIECE_PLANO.md, E3–E5).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_ilhas_mine_piece.gd
#
#  No MAPA VIVO (precisa dos .glb `mpe_*` na loja — arte fora do git):
#    • as 11 ilhas do cadastro têm placa e são detectadas;
#    • cada estrutura é SÓLIDA: um raio de cima bate na hitbox dela;
#    • em cada navio o jogador fica DE PÉ no convés e a tripulação não cai no mar;
#    • cada vendedor das lojas abre a loja com E por perto.
#    • (22/10/2026) chão sob cada construção = platô rente ao piso; árvores no chão (o relevo
#      em blocos que o jogo desenha), fora delas.
# ============================================================================

const Gerador := preload("res://tools/mapa_ilha/gerar_ilhas_mine_piece.gd")
const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")

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
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://test_ilhas_mine_piece.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_ilhas_mine_piece.json"))
	root.get_node("GameFlow").start_story()
	await quadros(240)
	var cena := current_scene
	# Sem o tipo `Player` (no `--script` compilaria antes dos autoloads).
	var jogador: Node3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)

	print("\n-- cadastro --")
	var caixas: Dictionary = cena.get("_ilhas").caixas
	for id in Ilhas.TABELA:
		ok(caixas.has(id), "ilha %s detectada" % id)

	print("\n-- estruturas sólidas --")
	var espaco := jogador.get_world_3d().direct_space_state
	var estruturas := cena.find_children(Gerador.PREFIXO + "*_estrutura_*", "", true, false) \
		+ cena.find_children(Gerador.PREFIXO + "*_loja_*", "", true, false)
	var solidas := 0
	var sem := []
	for e: Node3D in estruturas:
		if e.get_node_or_null("Modelo") == null:
			continue
		# Campo de trigo: o trigo não colide (como no Minecraft) e fica sobre o chão da ilha.
		if str(e.get_node("Modelo").get_meta("modelo_id")) == "mpe_village_shimotsuki_field":
			solidas += 1
			continue
		# Rua, campo e pátio ficam RENTES ao chão da ilha: o raio atravessa o que não é a
		# estrutura (terreno, personagem) até achar a hitbox dela.
		# 5 pontos da pegada: o meio de um campo pode ser água (o conversor tira a água).
		var t: Vector3 = BibliotecaDeModelos.padrao().tamanho_padrao(str(e.get_node("Modelo").get_meta("modelo_id")))
		var achou := false
		for d in [Vector3.ZERO, Vector3(0.25, 0, 0.25), Vector3(-0.25, 0, 0.25), Vector3(0.25, 0, -0.25), Vector3(-0.25, 0, -0.25)]:
			var c: Vector3 = e.global_position + e.global_transform.basis * (d * t)
			var q := PhysicsRayQueryParameters3D.create(c + Vector3.UP * 200.0, c - Vector3.UP * 100.0)
			for tentativa in 6:
				var hit := espaco.intersect_ray(q)
				if hit.is_empty():
					break
				if hit["collider"] == e or e.is_ancestor_of(hit["collider"]):
					achou = true
					break
				q.exclude = q.exclude + [hit["rid"]]
			if achou:
				break
		if achou:
			solidas += 1
		else:
			sem.append(e.name)
	ok(estruturas.size() > 0 and sem.is_empty(), "%d/%d estruturas e lojas com hitbox no centro %s" % [solidas, estruturas.size(),
		"" if sem.is_empty() else str(sem)])

	print("\n-- navios: de pé no convés, tripulação a bordo --")
	var bib := BibliotecaDeModelos.padrao()
	var relatorio := {}
	for r: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(Gerador.RELATORIO)):
		relatorio["mpe_" + str(r["estrutura"])] = r
	var personagens := get_nodes_in_group("personagens_east_blue")
	for n: Node3D in cena.find_children(Gerador.PREFIXO + "*_navio_*", "", true, false):
		if n.get_node_or_null("Modelo") == null or "tripulante" in n.name:
			continue
		var tripulacao := personagens.filter(func(p: Node3D): return Vector2(p.global_position.x - n.global_position.x,
			p.global_position.z - n.global_position.z).length() < 40.0 and p.global_position.y > Gerador.MAR + 2.0)
		# O jogador no convés: o 1º lugar de pé que o conversor achou no convés principal.
		var modelo := str(n.get_node("Modelo").get_meta("modelo_id"))
		var lugares_: Array = relatorio[modelo].get("lugares_conves", [])
		if lugares_.is_empty():
			print("  · %s: sem convés com folga 3×3 (barco pequeno, sem tripulação) — pulado" % n.name)
			continue
		var giro := Basis(Vector3.UP, n.rotation.y)
		var origem := n.global_position - giro * (bib.info(modelo)["centro"] as Vector3)
		var conves := origem + giro * Vector3(lugares_[0][0], lugares_[0][1], lugares_[0][2])
		jogador.global_position = conves + Vector3.UP * 0.5
		jogador.set("velocity", Vector3.ZERO)
		await quadros(90)
		# Caminhável = apoiado no navio, sem atravessar o convés. Não exige ficar no ponto: a
		# tripulação hostil empurra (a imunidade tira o dano, não o empurrão).
		var a_bordo := Vector2(jogador.global_position.x - n.global_position.x, jogador.global_position.z - n.global_position.z).length() < 45.0
		ok(jogador.call("is_on_floor") and a_bordo and jogador.global_position.y > conves.y - 0.6,
			"%s: jogador apoiado a bordo (y=%.1f, convés %.1f)" % [n.name, jogador.global_position.y, conves.y])
		# Hostis perseguem o jogador e podem descer ao porão: o que conta é ninguém cair NO MAR.
		var no_mar := tripulacao.filter(func(p: Node3D): return is_instance_valid(p) and p.global_position.y < Gerador.MAR + 1.0)
		if not tripulacao.is_empty():
			ok(no_mar.is_empty(), "%s: %d tripulantes a bordo, %d no mar" % [n.name, tripulacao.size(), no_mar.size()])

	print("\n-- relevo sob as construções e árvores (22/10/2026) --")
	_relevo_e_arvores(bib, relatorio)

	print("\n-- lojas: E abre o vendedor --")
	var npcs: NpcsDaIlha = cena.get("_npcs")
	var vendedores := npcs.npcs.filter(func(v: NpcDaIlha): return String(v.name).begins_with("Npc_" + Gerador.PREFIXO))
	ok(vendedores.size() == 33, "33 vendedores nas 11 ilhas (%d)" % vendedores.size())
	var abriram := 0
	for v: NpcDaIlha in vendedores:
		jogador.global_position = v.global_position + Vector3(0.0, 0.3, 0.0) + v.global_transform.basis.z * 1.2
		jogador.set("velocity", Vector3.ZERO)
		await quadros(4)
		if npcs.mais_perto() == v and npcs.interagir():
			abriram += 1
	ok(abriram == vendedores.size(), "E abre a loja de %d/%d vendedores" % [abriram, vendedores.size()])

	print("\n%d/%d" % [total - falhas, total])
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)


## No arquivo do mapa vivo: o chão sob a pegada de cada construção das ilhas novas é o
## platô, rente ao piso do molde (nem flutua nem enterra); cada ilha tem árvores, de base
## no chão e fora das pegadas.
func _relevo_e_arvores(bib: BibliotecaDeModelos, relatorio: Dictionary) -> void:
	var mapa: Dictionary = MapaArquivo.carregar(Gerador.MAPA)["mapa"]
	var terrenos: Array = (mapa["pecas"] as Array).filter(func(p: Dictionary): return p["tipo"] == "terreno")
	var chao := func(x: float, z: float) -> float:
		for t: Dictionary in terrenos:
			var pos: Vector3 = t["posicao"]
			var tam: Vector3 = t["tamanho"]
			if absf(x - pos.x) <= tam.x * 0.5 and absf(z - pos.z) <= tam.z * 0.5:
				return pos.y + TerrenoDoMapa.altura_local(t["relevo"], tam, x - pos.x, z - pos.z)
		return NAN
	for id in Gerador.ILHAS:
		var pre: String = Gerador.PREFIXO + id + "_"
		var pegadas: Array = []
		var pior := 0.0
		var n := 0
		for p: Dictionary in mapa["pecas"]:
			if not (String(p["id"]).begins_with(pre + "estrutura_") and not "_vendedor" in String(p["id"])):
				continue
			var modelo := str(p["modelo"])
			var giro := Basis(Vector3.UP, deg_to_rad((p["rotacao_graus"] as Vector3).y))
			var origem: Vector3 = (p["posicao"] as Vector3) - giro * (bib.info(modelo)["centro"] as Vector3)
			var piso: float = origem.y + int(relatorio[modelo].get("chao_blocos", 0)) * Gerador.METROS_POR_BLOCO
			var t := bib.tamanho_padrao(modelo)
			pegadas.append([Vector2(origem.x, origem.z), Vector2(t.x, t.z) * 0.5, (p["rotacao_graus"] as Vector3).y])
			for dx in [-0.45, -0.2, 0.0, 0.2, 0.45]:
				for dz in [-0.45, -0.2, 0.0, 0.2, 0.45]:
					var c := origem + giro * Vector3(dx * t.x, 0, dz * t.z)
					pior = maxf(pior, absf(chao.call(c.x, c.z) - piso))
			n += 1
		ok(n > 0 and pior <= 0.2, "%s: %d construções, chão sob a pegada a no máximo %.2f m do piso" % [id, n, pior])
		# Árvores pousam no relevo EM BLOCOS (o que o jogo desenha), não no liso.
		var blocos := RelevoEmBlocos.new()
		blocos.calcular_ou_ler(terrenos.filter(func(t: Dictionary) -> bool: return String(t["id"]).begins_with(pre)), id)
		var arvores := 0
		var ruins := []
		for p: Dictionary in mapa["pecas"]:
			if not String(p["id"]).begins_with(pre + "arvore_"):
				continue
			arvores += 1
			var pos: Vector3 = p["posicao"]
			var base := pos.y - (p["tamanho"] as Vector3).y * 0.5
			var h: float = blocos.altura(pos.x, pos.z)
			var dentro := pegadas.any(func(e: Array) -> bool:
				var q := (Vector2(pos.x, pos.z) - (e[0] as Vector2)).rotated(deg_to_rad(e[2])).abs() - (e[1] as Vector2)
				return q.x < 0.0 and q.y < 0.0)
			if dentro or base > h + 0.01 or base < h - 1.2:
				ruins.append(p["id"])
		ok(arvores > 0 and ruins.is_empty(), "%s: %d árvores no chão e fora das construções %s" % [id, arvores,
			"" if ruins.is_empty() else str(ruins.slice(0, 5))])

