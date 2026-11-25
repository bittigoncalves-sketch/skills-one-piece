extends SceneTree
## RECARGA POR TÉCNICA nas frutas do mod (12/11/2026): usar um poder bloqueia SÓ ele até o cronômetro acabar; os outros seguem livres.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_recarga_por_tecnica.gd
var total := 0
var falhas := 0
func _init() -> void:
	rodar.call_deferred()
func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)
func q(n: int) -> void:
	for i in n:
		await physics_frame
func rodar() -> void:
	MundoMinePiece.FATOR_DE_PROJETIL = 1.0
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_recarga_tecnica.json"))
	modo.set("progresso_forcado", "user://test_recarga_tecnica.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	j.max_health = 1.0e7
	j.health = 1.0e7
	j.max_energy = 2000.0
	for id in ["gomu_gomu", "mera_mera"]:
		modo.equipar_fruta(j, "")
		await q(5)
		modo.equipar_fruta(j, id)
		await q(10)
		var c = j.get_node("FrutaMinePiece")
		j.energy = j.max_energy
		var mapa: Dictionary = c.mapa_de_teclas()
		var teclas: Array = mapa.keys()
		ok(teclas.size() >= 2, "%s: ao menos 2 técnicas em teclas diretas (%s)" % [id, str(teclas)])
		var t1: String = teclas[0]
		var t2: String = teclas[1]
		var n1: int = int(mapa[t1])
		var n2: int = int(mapa[t2])
		# 1ª técnica: aperta e solta; espera acabar o golpe
		c._tecla_do_mod(t1, true)
		await q(6)
		c._tecla_do_mod(t1, false)
		await q(120)
		# o mod pôs o recarregamento global: ele foi reivindicado pela técnica usada
		var r1: float = c.recarga_da_tecnica(n1)
		ok(r1 > 0.0 or c._recargas.has(n1), "%s: a técnica usada (%d) ficou com o cronômetro (%.1f s)" % [id, n1, r1])
		ok(c.recarga_da_tecnica(n2) == 0.0, "%s: a OUTRA técnica (%d) está livre" % [id, n2])
		ok(not McEntidade.de(j).hasEffect(Mc.efeito("minepiece:cooldown_time")), "%s: o mod não segura mais o recarregamento global" % id)
		var estado: Array = c.estado_das_tecnicas()
		var e1: Dictionary = estado.filter(func(g): return int(g.get("numero", -1)) == n1 or str(g.tecla) == t1)[0]
		var e2: Dictionary = estado.filter(func(g): return str(g.tecla) == t2)[0]
		ok(float(e1.recarga) > 0.0 and float(e2.recarga) == 0.0, "%s: o HUD mostra recarga só na técnica usada (%.1f × %.1f)" % [id, float(e1.recarga), float(e2.recarga)])
		# a usada recusa enquanto recarrega; a outra começa
		var antes_selecao: int = c.selecao
		c._tecla_do_mod(t1, true)
		ok(c.selecao == antes_selecao or not c.ativo, "%s: apertar a tecla da técnica recarregando não a inicia" % id)
		c._tecla_do_mod(t1, false)
		await q(3)
		j.energy = j.max_energy
		c._tecla_do_mod(t2, true)
		await q(4)
		ok(c.selecao == n2, "%s: a outra técnica (%d) foi selecionada e inicia mesmo com a primeira recarregando" % [id, n2])
		c._tecla_do_mod(t2, false)
		await q(120)
		ok(c.recarga_da_tecnica(n2) > 0.0 or c._recargas.has(n2), "%s: ao usar a 2ª, ela ganha o seu próprio cronômetro" % id)
		# o cronômetro da 1ª corre sozinho até zerar
		c._recargas[n1] = 0.05
		await q(8)
		ok(c.recarga_da_tecnica(n1) == 0.0, "%s: acabado o cronômetro, a técnica volta a ficar livre" % id)
	print("test_recarga_por_tecnica: %d ok, %d falhas" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)
