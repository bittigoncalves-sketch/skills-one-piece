extends SceneTree
# ============================================================================
#  XP DE CADA ANIMAL PELA DIFICULDADE (08/10/2026). Idempotente.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/aplicar_xp_por_dificuldade.gd
#
#  Pedido do dono: "modificar a experiência recebida por matar cada animal com base na
#  dificuldade de cada um" (era 1 XP para todos). Grava no catálogo SÓ o campo `xp` da
#  ficha de cada animal (`FichaDeAnimal.xp_por_dificuldade`: vida/10 × (1 + dano/2));
#  o resto da ficha fica como está (a `aplicar_fichas_de_animais.gd` reescreveria a
#  ficha inteira e apagaria o que outras ferramentas acrescentaram, como `golpe_em`).
#  O dono pode trocar o XP de uma espécie pelo editor depois; rodar de novo volta à
#  regra.
# ============================================================================


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var erros := 0
	var n := 0
	for id in bib.ids():
		var ficha := bib.ficha_de_animal(id)
		if ficha.is_empty():
			continue
		var antes := int(ficha.get("xp", 1))
		ficha["xp"] = FichaDeAnimal.xp_por_dificuldade(ficha)
		erros += int(bib.definir_ficha_de_animal(id, ficha) != OK)
		n += 1
		print("XP %-30s %-11s vida %6.0f dano %3.0f%s  %d -> %d" % [id, ficha["comportamento"], float(ficha["vida"]),
			float(ficha.get("dano", 0.0)), "  CHEFE" if ficha.get("boss", false) else "", antes, int(ficha["xp"])])
	print("XP_POR_DIFICULDADE %d animais erros=%d" % [n, erros])
	quit(1 if erros else 0)
