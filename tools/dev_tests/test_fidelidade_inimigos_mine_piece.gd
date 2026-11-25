extends SceneTree
# ============================================================================
#  PORTÃO DE FIDELIDADE DOS INIMIGOS (24/10/2026, decisão do dono): habilidade de inimigo = a do mod, nada do
#  skill builder (ele limita o que se importa). Para CADA ficha do jogo:
#    • a ficha existe nos dados extraídos do mod (`entidades_do_mod.json`);
#    • o modelo do mod (mp_<id>.glb) existe e traz animações;
#    • com procedure no `baseTick` do mod: a IA do mod está montada e é ELA quem dirige as técnicas (o cérebro só persegue);
#    • sem procedure (o mod só tem MeleeAttackGoal): ficha `faccao: "mod"` sem tabela de técnicas nossa;
#    • ficha importada do mod (`faccao: "mod"`) nunca carrega tabela do skill builder.
#  Os 42 do East Blue têm, herdadas, `tecnicas` do skill builder: contadas como LEGADO (plano B) — sem efeito com a IA do mod.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_fidelidade_inimigos_mine_piece.gd
# ============================================================================

var total := 0
var falhas := 0


func _init() -> void:
	_rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	if not cond:
		falhas += 1
		print("  ❌ " + msg)


func _rodar() -> void:
	await process_frame
	var mod: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://mapas/east_blue/entidades_do_mod.json"))["entidades"]
	var fichas: Array = JSON.parse_string(FileAccess.get_file_as_string("res://mapas/east_blue/personagens.json"))["personagens"]
	var legado := 0
	var com_ia := 0
	var so_melee := 0
	for f: Dictionary in fichas:
		var id := str(f["id"])
		var m: Dictionary = mod.get(id, {})
		if bool(f.get("original", false)):          # personagem NOSSO, não do mod (macacos humanoides da Ilha dos Macacos, 18/11/2026): sem procedure do mod para conferir
			continue
		if id == "pirate_fishman":                  # variante nossa do Pirata (pele homem-peixe do raid do Arlong)
			continue
		ok(not m.is_empty(), "%s: existe em entidades_do_mod.json" % id)
		var glb := "res://mapas/modelos/%s.glb" % f["modelo"]
		var cena: PackedScene = load(glb) as PackedScene if ResourceLoader.exists(glb) else null
		ok(cena != null, "%s: modelo %s" % [id, glb])
		if cena != null:
			var n := cena.instantiate()
			var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
			ok(ap != null and not ap.get_animation_list().is_empty(), "%s: o modelo traz animações do mod" % id)
			n.free()
		var tem_tick: bool = not (m.get("tick", []) as Array).is_empty()
		if tem_tick:
			com_ia += 1
		else:
			so_melee += 1
			ok(str(f.get("faccao")) == "mod" or id in ["pirate"], "%s: sem procedure no mod → só MeleeAttackGoal (facção mod)" % id)
		if str(f.get("faccao")) == "mod":
			ok((f.get("tecnicas", []) as Array).is_empty() and (f.get("comuns", []) as Array).is_empty(),
				"%s: ficha importada não carrega tabela do skill builder" % id)
		elif not (f.get("tecnicas", []) as Array).is_empty():
			legado += 1
	# A IA do mod dirige: monta um personagem com procedure e confere o cérebro.
	var p := PersonagemMinePiece.new()
	p.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	root.add_child(p)
	await process_frame
	ok(IaDoMod.ligada and p.cerebro._ia_do_mod_dirige(), "arlong: a IA do mod dirige as técnicas (o cérebro só persegue)")
	print("fichas %d | com procedure no baseTick %d | só melee %d | legado skill builder (plano B) %d" % [fichas.size(), com_ia, so_melee, legado])
	print("%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
