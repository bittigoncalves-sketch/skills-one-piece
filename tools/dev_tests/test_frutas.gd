extends SceneTree
## ============================================================================
##  AUDITORIA DAS AKUMA NO MI — o que está funcional e o que não está.
##
##  Sobe o JOGO DE VERDADE (Main.tscn via GameFlow) e, para cada fruta, mede:
##
##   1. OBTÍVEL  — existe árvore que dá essa fruta no mapa?
##   2. EQUIPA   — `equip_fruit` grava o id e a passiva é aplicada?
##   3. Z/X/C/V  — o golpe SAI? Mede pelo que ele produz no mundo:
##                 zona de dano criada, nós de efeito criados, e erros no meio.
##   4. VAZA     — depois do golpe terminar, sobra nó pendurado no mundo?
##
##  Por que medir o MUNDO e não o retorno da função: `_fire_skill` não devolve
##  nada e engole quase tudo. Um golpe pode "rodar" sem criar hitbox nenhuma —
##  foi exatamente assim que 3 frutas ficaram meses dando os golpes da Gomu Gomu
##  sem ninguém ver (docs/erros.md, 2026-08-10).
##
##  Uso:
##    godot --headless --path . --script tools/dev_tests/test_frutas.gd
##    godot --headless --path . --script tools/dev_tests/test_frutas.gd -- mera_mera
## ============================================================================

const ESPERA_POS_GOLPE := 8.0    # generoso: efeito longo (tornado, gelo) nao pode virar falso "vazamento"
const SLOTS := ["Z", "X", "C", "V"]

var _player: Node = null
var _main: Node = null
var _relatorio: Dictionary = {}

func _init() -> void:
	await process_frame
	var gf := get_root().get_node("GameFlow")
	gf.start_singleplayer()
	await _esperar(3.0)

	_main = current_scene
	_player = _local()
	if _player == null:
		print("❌ não achei o jogador — a cena não subiu")
		quit(1)
		return

	# ⚠️ CONGELA O RELÓGIO DA RODADA.
	#
	# Este teste mede FRUTAS, não regra de partida — mas as duas se cruzam de um
	# jeito que só apareceu quando a rodada caiu de 10 para 5 minutos
	# (2026-08-12): o teste leva ~327 s, e ao fim da rodada o `Scoreboard`
	# dispara o pódio, que força respawn de TODO MUNDO
	# (`Scoreboard._start_podium` -> `_order_respawn`). O respawn devolve a fruta
	# à árvore — e os golpes restantes saem vazios, acusando "NÃO PRODUZIU NADA"
	# num código que está correto.
	#
	# Travar o relógio é mais honesto do que encurtar o teste: a duração da
	# rodada é decisão de jogo e não pode ficar refém do tempo de medição.
	var placar := get_first_node_in_group("scoreboard")   # em `extends SceneTree` NAO existe get_tree(): o script E a arvore
	if placar:
		placar.time_left = 1.0e9
		print("⏸  relógio da rodada congelado (o pódio devolveria a fruta no meio)")

	var pedidas := PackedStringArray(OS.get_cmdline_user_args())
	var skills: Dictionary = SkillSystem.get_fruit_skills()
	var com_arvore := _ids_das_arvores()

	var alvos: Array = []
	for k in skills.keys():
		if pedidas.is_empty() or pedidas.has(str(k)):
			alvos.append(str(k))
	alvos.sort()

	print("\n╔══════════════════════════════════════════════════════════════╗")
	print("║  AUDITORIA DAS AKUMA NO MI                                   ║")
	print("╚══════════════════════════════════════════════════════════════╝")
	print("frutas com skills: %d | árvores no mapa: %d" % [skills.size(), com_arvore.size()])

	for fid in alvos:
		await _auditar(fid, com_arvore)

	_resumo()
	quit()

# ------------------------------------------------------------------ auditoria
func _auditar(fid: String, com_arvore: Array) -> void:
	print("\n────────────────────────────────────────────────────────────")
	print("🍎 ", fid.to_upper())
	var r := {"obtivel": com_arvore.has(fid), "equipa": false, "slots": {}, "vaza": {}}

	# --- 1/2. equipar ---
	_player.equip_fruit(fid)
	await _esperar(0.4)
	r["equipa"] = (str(_player.current_fruit_id) == fid)
	print("   obtível numa árvore ....... %s" % ("SIM" if r["obtivel"] else "NÃO (sem árvore no mapa)"))
	print("   equipa corretamente ....... %s" % ("SIM" if r["equipa"] else "NÃO (ficou '%s')" % _player.current_fruit_id))

	# --- 3/4. os quatro golpes ---
	for slot in SLOTS:
		var identidade: Dictionary = SkillSystem.get_fruit_skills().get(fid, {})
		var declarada: Dictionary = identidade.get(slot, {})
		if bool(declarada.get("desabilitado", false)):
			r["slots"][slot] = {"criou": 0, "hitbox": false, "desabilitada": true}
			r["vaza"][slot] = 0
			print("   %s: desabilitada por projeto" % slot)
			continue
		var antes := _contar_nos(_main)
		var zonas_antes := _contar_tipo(_main, "DamageZone")
		_player._skill_cooldowns[slot] = 0.0
		_player.set_meta("is_casting", false)
		_player._cast.abortar()   # `_charging` virou vista sem setter (passo 6c)
		_player._rapid_fire = false
		# ⚠️ ERA `_player._movement_locked_timer = 0.0`, e a propriedade não existe
		# mais desde que a FSM assumiu a trava de movimento (`Player.gd:107`). A
		# auditoria morria aqui, na PRIMEIRA fruta, e imprimia o resumo vazio —
		# quebra anterior a esta refatoração, encontrada ao rodá-la.
		_player.lock_movement(0.0, "")
		_player.energy = _player.max_energy

		var origem: Vector3 = _player.global_position + Vector3.UP
		_player._fire_skill(slot, Vector3(0, 0, -1), origem)

		# AMOSTRAGEM CONTÍNUA, não num instante só.
		# Medir uma vez em t=0.9s dava falso negativo em golpe com wind-up longo:
		# o Gomu Pistol, por exemplo, só cria a hitbox depois do braço esticar. O
		# pico e a hitbox são procurados ao longo de TODA a janela.
		var pico := antes
		var zonas := zonas_antes
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < int((0.9 + ESPERA_POS_GOLPE) * 1000.0):
			pico = maxi(pico, _contar_nos(_main))
			zonas = maxi(zonas, _contar_tipo(_main, "DamageZone"))
			await process_frame
		var depois := _contar_nos(_main)

		var criou := pico - antes
		var sobrou := depois - antes
		var fez_hitbox := (zonas - zonas_antes) > 0
		r["slots"][slot] = {"criou": criou, "hitbox": fez_hitbox}
		r["vaza"][slot] = sobrou

		var veredito := "OK"
		if criou <= 0:
			veredito = "❌ NÃO PRODUZIU NADA"
		elif not fez_hitbox:
			veredito = "⚠ sem hitbox (só visual)"
		if sobrou > 0:
			veredito += "  🔴 VAZOU %d nó(s)" % sobrou
		print("   %s: criou %3d nós | hitbox %s | sobrou %2d  -> %s"
			% [slot, criou, "SIM" if fez_hitbox else "não", sobrou, veredito])

	_relatorio[fid] = r

# --------------------------------------------------------------------- resumo
func _resumo() -> void:
	print("\n╔══════════════════════════════════════════════════════════════╗")
	print("║  RESUMO                                                      ║")
	print("╚══════════════════════════════════════════════════════════════╝")
	print("%-16s %-8s %-7s %-22s %s" % ["fruta", "obtível", "equipa", "golpes com hitbox", "vazamento"])
	var sem_arvore: Array = []
	var quebradas: Array = []
	var vazando: Array = []
	for fid in _relatorio:
		var r: Dictionary = _relatorio[fid]
		var ok := 0
		var ativas := 0
		var mudos: Array = []
		for s in SLOTS:
			if bool(r["slots"][s].get("desabilitada", false)):
				continue
			ativas += 1
			if bool(r["slots"][s]["hitbox"]):
				ok += 1
			elif int(r["slots"][s]["criou"]) <= 0:
				mudos.append(s)
		var vaz := 0
		for s in SLOTS:
			vaz += int(r["vaza"][s])
		print("%-16s %-8s %-7s %d/%d %-18s %s" % [
			fid,
			"sim" if r["obtivel"] else "NÃO",
			"sim" if r["equipa"] else "NÃO",
			ok, ativas,
			("(mudos: %s)" % ", ".join(mudos)) if not mudos.is_empty() else "",
			("%d nós" % vaz) if vaz > 0 else "-"])
		if not r["obtivel"]:
			sem_arvore.append(fid)
		if ok < ativas:
			quebradas.append(fid)
		if vaz > 0:
			vazando.append(fid)

	print("\nPENDÊNCIAS")
	print("  sem árvore (não dá pra pegar jogando): %s" % (", ".join(sem_arvore) if sem_arvore else "nenhuma"))
	print("  golpes sem hitbox ou mudos ..........: %s" % (", ".join(quebradas) if quebradas else "nenhuma"))
	print("  vazando nós no mapa .................: %s" % (", ".join(vazando) if vazando else "nenhuma"))

# ------------------------------------------------------------------ utilidades
func _local() -> Node:
	for p in get_root().get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p
	return null

func _ids_das_arvores() -> Array:
	var out: Array = []
	for d in TreeAndFruitGenerator.get_tree_definitions():
		out.append(str(d.get("id", "")))
	return out

func _contar_nos(n: Node) -> int:
	var t := 1
	for c in n.get_children():
		t += _contar_nos(c)
	return t

# ⚠️ O RECONHECIMENTO POR CAMINHO DE SCRIPT NÃO ENXERGA SUBCLASSE (2026-09-06).
#
# `get_class()` devolve a classe do ENGINE ("Area3D"), nunca o `class_name` do
# GDScript — por isso o teste caía no `resource_path.ends_with("DamageZone.gd")`.
# Só que esse casamento é por ARQUIVO: um nó de uma subclasse tem o
# `resource_path` do arquivo DELA, e some da conta.
#
# Foi o que aconteceu quando o C da Pika passou a usar `ZonaBarragem extends
# DamageZone`: a auditoria reportou "3/4 golpes com hitbox" num golpe que o
# `test_pika_c_area` prova aplicar dano e paralisia. A hitbox existia; a sonda é
# que era estreita demais para vê-la.
#
# `is DamageZone` cobre a hierarquia inteira e é o que o teste sempre quis
# perguntar. Os outros tipos seguem no casamento por caminho — nenhum deles tem
# subclasse hoje, e generalizar sem necessidade seria trocar um teste legível
# por um genérico.
func _contar_tipo(n: Node, tipo: String) -> int:
	var t := 0
	if tipo == "DamageZone":
		if n is DamageZone:
			t += 1
	elif n.get_class() == tipo or (n.get_script() != null and str(n.get_script().resource_path).ends_with(tipo + ".gd")):
		t += 1
	for c in n.get_children():
		t += _contar_tipo(c, tipo)
	return t

func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame
